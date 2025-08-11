# Monitoring per volume metrics with kubelet

## Why monitor per volume stats from kubelet?

Since the `kubelet` is a component that runs on every Kubernetes node (worker and control plane), it makes it a great candidate to gather and expose node level metrics. This includes per volume metrics, provided:

- The volume is a CSI volume (This did not work for Rancher `local-path` volumes in my testing)
- The volume is attached to a node. When a volume is attached, mounted and being accessed, the `kubelet` process running locally on the node that it is mounted on can provide metrics.

Both of these are requirements that can be satisfied out-of-the-box for PVCs provisioned using `csi.weka.io` as the provisioner.

## How does this work?

`kubelet` exposes several metrics by default. See https://kubernetes.io/docs/reference/instrumentation/metrics/ for reference.
Most k8s distributions expose kubelet’s metrics by default.

You can confirm the metrics are accessible by deploying Prometheus and checking all available metrics. By default, a Prometheus installation will scrape Kubelet metrics.
