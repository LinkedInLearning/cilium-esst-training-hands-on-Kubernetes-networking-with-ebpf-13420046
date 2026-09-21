# Chapter 3: IP Address Management

> ⚠️ **PLACEHOLDER** — the "Expect output" blocks below are illustrative samples and will be replaced with real captured output before release.

Companion files for Chapter 3. Each step lists the command to run and the output to expect. The full walkthrough is in the course videos.

## Setup

Create a cluster and install Cilium with the default Cluster Scope (cluster-pool) IPAM:
```shell
kind create cluster --config kind.yaml
cilium install --version "${CILIUM_VERSION:-1.20.2}"
cilium status --wait
```

## 3.2 Node IPs, pod IPs, and why IPs aren't identity

Run:
```shell
kubectl get ciliumnodes -o custom-columns='NODE:.metadata.name,PODCIDRS:.spec.ipam.podCIDRs'
```

Expect output such as:
```
NODE                 PODCIDRS
kind-control-plane   [10.244.0.0/24]
kind-worker          [10.244.2.0/24]
kind-worker2         [10.244.1.0/24]
```

## 3.4 Cluster Scope IPAM (the Cilium default)

Cluster Scope (a.k.a. cluster-pool) is the default: the Cilium **operator**, not Kubernetes, allocates a PodCIDR per node. Watch it in the operator logs:
```shell
kubectl -n kube-system logs deploy/cilium-operator | grep -iE "allocated .*cidr"
```

Expect output such as:
```
msg="Allocated v4CIDR" nodeName=kind-worker
msg="Allocated existing CIDRs" nodeName=kind-worker cidrs=10.244.2.0/24 allocated=true
```

Verify the per-node CIDRs on the CiliumNode objects:
```shell
kubectl get ciliumnodes -o custom-columns='NODE:.metadata.name,PODCIDRS:.spec.ipam.podCIDRs'
```

Expect output such as:
```
NODE                 PODCIDRS
kind-control-plane   [10.244.0.0/24]
kind-worker          [10.244.2.0/24]
kind-worker2         [10.244.1.0/24]
```

## 3.5 Multi-pool IPAM

Multi-pool lets different tenants draw from different IP ranges. It needs a different Cilium config, so start from a fresh cluster installed with `multi-pool.yaml`:
```shell
kind delete cluster
kind create cluster --config kind.yaml
helm repo add cilium https://helm.cilium.io/
helm install cilium cilium/cilium --namespace kube-system --version "${CILIUM_VERSION:-1.20.2}" --values multi-pool.yaml
cilium status --wait
```

Create a namespace and a pool per tenant:
```shell
kubectl create ns acme
kubectl create ns foobar
kubectl apply -f acme-pool.yaml -f foobar-pool.yaml
```

Bind each namespace to its pool with an annotation, then deploy a pod in each:
```shell
kubectl annotate ns acme   ipam.cilium.io/ip-pool=acme-pool
kubectl annotate ns foobar ipam.cilium.io/ip-pool=foobar-pool
kubectl -n acme   run client --image=nicolaka/netshoot -- sleep infinity
kubectl -n foobar run client --image=nicolaka/netshoot -- sleep infinity
kubectl get pods -A -o wide | grep -E 'acme|foobar'
```

Expect output such as (acme from `10.20.0.0/16`, foobar from `10.30.0.0/16`):
```
acme     client   1/1   Running   10.20.0.5    kind-worker2
foobar   client   1/1   Running   10.30.0.12   kind-worker2
```

## Clean up

Delete the cluster when you're done:
```shell
kind delete cluster
```
