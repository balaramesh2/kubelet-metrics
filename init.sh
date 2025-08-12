#!/bin/bash

#Adjust these variables 
export QUAY_USERNAME=''
export QUAY_PASSWORD=''
export AWS_ACCESS_KEY_ID=""
export AWS_SECRET_ACCESS_KEY=""
export AWS_SESSION_TOKEN=""
export SUBNET_ID="subnet-0497cdc65a68a3692"
export REGION="us-east-1"
export SG_ID="sg-089b10b6c408e6ebe"
##KEYPAIR_NAME is set to the name of your AWS EC2 keypair. This is used to SSH to nodes running k8s.
export KEYPAIR_NAME="balaramesh"
export CLUSTER_NAME="bala"
export WEKA_EMAIL="bala.ramesh@weka.io"
export KUBECONFIG="${HOME}/kube-${CLUSTER_NAME}.yaml"

# wipe screen.
clear

echo "Beginning run"
echo "...\n...\n...\n"

# Check the helm installation.

echo "Checking if Helm is installed..."
command -v helm version --short >/dev/null 2>&1 || { echo >&2 "Helm version 3+ is required but not installed yet... download and install here: https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3"; exit; }

# Check the kubectl installation.
echo "Checking if kubectl is installed..."
command -v kubectl version >/dev/null 2>&1 || { echo >&2 "Kubectl is required but not installed yet... download and install: https://kubernetes.io/docs/tasks/tools/"; exit; }

# Check the bliss installation.
echo "Checking if bliss is installed..."
command -v bliss version >/dev/null 2>&1 || { echo >&2 "Bliss is required but not installed yet... download and install: https://github.com/weka/bliss/releases"; exit; }

## Deploy k8s cluster.

echo "Deploying kubernetes cluster in AWS using bliss...."

bliss provision aws-k3s --cluster-name $CLUSTER_NAME \
	--subnet-id $SUBNET_ID \
	--security-groups $SG_ID --region $REGION \
	--ami-id ami-096514dba491a92ff --key-pair-name $KEYPAIR_NAME \
	--iam-profile-arn arn:aws:iam::459693375476:instance-profile/bliss-k3s-instance-profile \
	--tag Owner=$WEKA_EMAIL --tag TTL=2h --tag OwnerService=port \
	--template aws_k3_small --cluster-name $CLUSTER_NAME \
	--ssh-usernames ubuntu 2>&1 | tee -a blissout

echo "Kubernetes cluster deployment complete...."

## Access k8s cluster.
echo "Status of nodes in the cluster...."

kubectl --kubeconfig "${KUBECONFIG}" get nodes

if [ $? -ne 0 ]; then
  echo
	echo "$(error) Error occurred during kubectl get nodes???."
	echo
	exit;
fi

echo "Deploy Weka operator and then install wekaCluster..."

## Install weka operator v1.6.0 and use WEKA image 4.4.5.118-k8s.3 for wekaCluster

bliss install --cluster-name $CLUSTER_NAME \
	--operator-version v1.6.0 --csi-version 2.7.2 \
	--quay-username=$QUAY_USERNAME --quay-password=$QUAY_PASSWORD \
	--kubeconfig $KUBECONFIG \
	--weka-image quay.io/weka.io/weka-in-container:4.4.5.118-k8s.3 \
	--client-weka-image quay.io/weka.io/weka-in-container:4.4.5.118-k8s.3 2>&1 | tee -a blissout

echo "Weka operator deployment complete..."

echo "Examining status of pods in weka namespace...Pods should be up and running..."

kubectl --kubeconfig "${KUBECONFIG}" wait --for=condition=Ready pod --all --timeout=100s --namespace weka-operator-system

echo "Check status of wekaCluster...It should be in the Ready state..."

kubectl --kubeconfig "${KUBECONFIG}" get wekacluster --all-namespaces

echo "Installing Prometheus and Grafana using Helm..."

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

kubectl --kubeconfig "${KUBECONFIG}" create ns prometheus
kubectl --kubeconfig "${KUBECONFIG}" create ns grafana

helm install prometheus prometheus-community/prometheus --namespace prometheus -f values-prom.yaml

helm install grafana grafana/grafana --namespace grafana -f values-graf.yaml
