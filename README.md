# Visualize WEKA Metrics with Prometheus and Grafana

## TLDR;
```
## Populate AWS and QUAY environment variables in init.sh
sh init.sh
```

## Why Visualize WEKA Metrics?

Kubernetes is a platform. Kubernetes administrators may only have visibility into workloads in Kubernetes! This makes it necessary for valuable storage-related metrics to be available in k8s.

The WEKA Operator exposes useful metrics related to cluster health, filesystem usage information, CPU utilization, and more!

This repo helps you kickstart your WEKA k8s visualization journey. 

Use the `init.sh` script to:
- deploy a k8s cluster in AWS.
- deploy containerized WEKA running on the k8s cluster.
- install Prometheus and Grafana. Pre-configure dashboards using `values-prom.yaml` and `values-graf.yaml`!

## How does it work?

Newer releases of the WEKA operator [`v1.6.0` and above] deploy a node agent when the operator is installed. The node agent is capable of retrieving WEKA metrics from each node in a Kubernetes cluster. 

These WEKA metrics can be scraped using Prometheus, and visualized using Grafana.

Administrators can define dashboards as `json` manifests, promoting reusability.

## Great! How do I begin?

### Step 1: Clone repo
```
git clone <>
```
### Step 2: Update `init.sh`
Provide your  variables (`AWS_*`, `QUAY_*`). Modify defaults if necessary.

### Step 3: Run `init.sh`

### Step 4: Access Grafana dashboard!
