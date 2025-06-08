# k8s-lab

Local Kubernetes lab environment

## How to

Clusters are deployed and managed using [Cluster API](https://cluster-api.sigs.k8s.io/).

Prerequisites:

- [kubectl](https://kubernetes.io/docs/reference/kubectl/)
- [Docker](https://www.docker.com/)
- [kind](https://kind.sigs.k8s.io/)
- [Helm](https://helm.sh/)
- [clusterctl](https://cluster-api.sigs.k8s.io/clusterctl/overview)
- [Flux](https://fluxcd.io/)

### Initialize the management cluster

The management cluster manages the lifecycle of workload clusters.

First, create a local cluster that will act as a management cluster:

```bash
kind create cluster --config ./clusters/management.yaml
kubectl cluster-info
```

Now initialize the management cluster:

```bash
export CLUSTER_TOPOLOGY=true
clusterctl init --infrastructure docker --addon helm
```

### Create worker clusters

Worker clusters are defined by Kubernetes API objects. You may use an existing cluster defined in [clusters](./clusters/), or generate configuration for a new worker cluster like so:

```bash
clusterctl generate cluster lab \
  --flavor development \
  --kubernetes-version v1.29.7 \
  --control-plane-machine-count=1 \
  --worker-machine-count=2
```

As of writing, the `generate` command will create a cluster using both a MachineDeployment and a MachinePool. This results in twice the number of nodes than what you specify. You may want to disable one of these by modifying the resulting yaml.

Apply the manifests to create the worker cluster:

```bash
export CLUSTER_TOPOLOGY=true
kubectl apply -f clusters/lab.yaml
```

The provisioning status of the worker cluster can be checked with:

```bash
kubectl get cluster
```

If the cluster is unable to provisioning, refer to the [Troubleshooting guide](https://cluster-api.sigs.k8s.io/user/troubleshooting.html#troubleshooting-quick-start-with-docker-capd). On Linux, you may need to [increase inotify limits](https://cluster-api.sigs.k8s.io/user/troubleshooting.html#cluster-api-with-docker----too-many-open-files).

Once the cluster is provisioning cluster credentials may be obtained like so:

```bash
clusterctl get kubeconfig lab > lab.kubeconfig
```

You may merge the kubeconfig with your existing configuration like so:

```bash
export KUBECONFIG=~/.kube/config:./lab.kubeconfig

kubectl config view --flatten > ./flattened.kubeconfig

mv ./flattened.kubeconfig ~/.kube/config
```

### Bootstrap FluxCD

Install flux on the cluster:

```bash
flux install \
  --namespace flux-system
```

Create a Git source that points to the manifest repository:

```bash
flux create source git root \
  --url=https://github.com/eric-carlsson/k8s-lab \
  --branch=main \
  --interval 1m
```
Create a root kustomization to sync from the source:

```bash
flux create ks root \
  --source=GitRepository/root \
  --path=clusters/lab \
  --prune=true \
  --interval=15m \
  --wait=true
```

Additional sources and kustomizations can be created declaratively in the repository.
