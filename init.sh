#!/bin/bash

#Adjust these variables 
export REGION="us-east-1"
export SG_ID="sg-089b10b6c408e6ebe"
##KEYPAIR_NAME is set to the name of your AWS EC2 keypair. This is used to SSH to nodes running k8s.
export KEYPAIR_NAME="balaramesh"
export CLUSTER_NAME="brb-graf"
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

# Checking if k8s cluster already exists...
echo "Checking if k8s cluster already exists from previous bliss run..."

function check_cluster() {
	command bliss info --cluster-name ${CLUSTER_NAME}

#command -v bliss info --cluster-name ${CLUSTER_NAME} >/dev/null 2>&1 || { echo >&2 "Cluster does not exist...you are safe to continue..."; continue; }

#command -v bliss info --cluster-name ${CLUSTER_NAME} >/dev/null 2>&1 || { echo >&1 "Cluster already exists...exiting.."; exit; }
	echo "Does cluster exist? If yes, then enter yes. If no, then enter no."
	
	read local CLUSTER_EXIST

	if [[ "$CLUSTER_EXIST" == "yes" ]]; then
		echo "Cluster already exists....exiting...."
		return 1
	elif [[ "$CLUSTER_EXIST" == "no" ]]; then
		echo "Cluster does not exist..provisioning one now..."
		return 0
	fi
	}

local clustercheck=check_cluster()

## Deploy k8s cluster if it doesn't exist.

if [[ "$clustercheck" == 0 ]]; then
	echo "Deploying kubernetes cluster in AWS using bliss...."
	command bliss provision aws-k3s --cluster-name $CLUSTER_NAME \
		--subnet-id $SUBNET_ID \
		--security-groups $SG_ID --region $REGION \
		--ami-id ami-096514dba491a92ff --key-pair-name $KEYPAIR_NAME \
		--iam-profile-arn arn:aws:iam::459693375476:instance-profile/bliss-k3s-instance-profile \
		--tag Owner=$WEKA_EMAIL --tag TTL=2h --tag OwnerService=port \
		--template aws_k3_small --cluster-name $CLUSTER_NAME \
		--ssh-usernames ubuntu
fi

#if [ $? -ne 0 ]; then
#	echo
#	echo "Error occurred during K8s cluster provisioning..."
#	echo
#	exit;
#fi

echo "Kubernetes cluster deployment complete...."

## Access k8s cluster.
echo "Status of nodes in the cluster...."

command kubectl --kubeconfig "${KUBECONFIG}" get nodes

if [ $? -ne 0 ]; then
  echo
	echo "Error occurred during kubectl get nodes???."
	echo
	exit;
fi

echo "Deploy Weka operator and then install wekaCluster..."

## Install weka operator v1.6.0 and use WEKA image 4.4.5.118-k8s.3 for wekaCluster

command bliss install --cluster-name $CLUSTER_NAME \
	--operator-version v1.6.0 --csi-version 2.7.2 \
	--quay-username=$QUAY_USERNAME --quay-password=$QUAY_PASSWORD \
	--kubeconfig $KUBECONFIG \
	--weka-image quay.io/weka.io/weka-in-container:4.4.5.118-k8s.3 \
	--client-weka-image quay.io/weka.io/weka-in-container:4.4.5.118-k8s.3 2>&1 | tee -a blissout

if [ $? -ne 0 ]; then
        echo
        echo "Error occurred during weka operator install + wekaCluster provisioning..."
        echo
        exit;
fi

echo "Weka operator deployment complete..."

echo "Examining status of pods in weka namespace...Pods should be up and running..."

command kubectl --kubeconfig "${KUBECONFIG}" wait --for=condition=Ready pod --all --timeout=100s --namespace weka-operator-system

if [ $? -ne 0 ]; then
        echo
        echo "Error accessing k8s cluster. Check your KUBECONFIG variable??"
        echo
        exit;
fi

echo "Check status of wekaCluster...It should be in the Ready state..."

command kubectl --kubeconfig "${KUBECONFIG}" get wekacluster --all-namespaces

if [ $? -ne 0 ]; then
        echo
        echo "Error accessing k8s cluster. Check your KUBECONFIG variable??"
        echo
        exit;
fi

echo "Installing Prometheus and Grafana using Helm..."

command helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
command helm repo add grafana https://grafana.github.io/helm-charts
command helm repo update

command kubectl --kubeconfig "${KUBECONFIG}" create ns prometheus
command kubectl --kubeconfig "${KUBECONFIG}" create ns grafana

command helm install prometheus prometheus-community/prometheus --kubeconfig "${KUBECONFIG}" --namespace prometheus -f values-prom.yaml

command helm install grafana grafana/grafana --kubeconfig "${KUBECONFIG}" --namespace grafana -f values-graf.yaml

if [ $? -ne 0 ]; then
        echo
        echo "Error installing Prometheus and Grafana using Helm. Check your KUBECONFIG variable??"
        echo
        exit;
fi

echo "Waiting for Prometheus and Grafana to be installed..."

command kubectl --kubeconfig "${KUBECONFIG}" wait --for=condition=Ready pod --all --timeout=200s --namespace grafana

if [ $? -ne 0 ]; then
        echo
        echo "Error installing Prometheus and Grafana using Helm. Check your KUBECONFIG variable??"
        echo
        exit;
fi

echo "Exposing Grafana and Prometheus UI..."

command kubectl --kubeconfig "${KUBECONFIG}" expose service prometheus-server --namespace prometheus --type=NodePort --target-port=9090 --nodePort=32613 --name=prometheus-server-ext

if [ $? -ne 0 ]; then
        echo
        echo "Error accessing k8s cluster. Check your KUBECONFIG variable??"
        echo
        exit;
fi

command kubectl --kubeconfig "${KUBECONFIG}" expose service grafana --namespace grafana --type=NodePort --target-port=3000 --nodePort=31668 --name=grafana-ext

if [ $? -ne 0 ]; then
        echo
        echo "Error accessing k8s cluster. Check your KUBECONFIG variable??"
        echo
        exit;
fi

echo "Access Grafana UI using the address https://node-name:31668"

command kubectl --kubeconfig "${KUBECONFIG}" get nodes

echo "Credentials for Grafana UI are username:admin and password is below..."

echo "admin:" || command kubectl --kubeconfig "${KUBECONFIG}" get secret --namespace grafana grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo

if [ $? -ne 0 ]; then
        echo
        echo "Error accessing k8s cluster. Check your KUBECONFIG variable??"
        echo
        exit;
fi

echo "Access Grafana UI and navigate to dashboards folder!..."
