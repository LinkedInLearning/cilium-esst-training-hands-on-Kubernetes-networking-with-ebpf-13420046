# Chapter 4: Datapath

Companion files for Chapter 4. Each step lists the command to run and the output to expect. The full walkthrough is in the course videos.

## Setup

Create a cluster and install Cilium:
```shell
kind create cluster --config kind.yaml
cilium install --version "${CILIUM_VERSION:-1.20.2}"
cilium status --wait
```

## 4.1 Intranode connectivity

Deploy two pods pinned to the same node:
```shell
kubectl apply -f intra-node-example.yaml
kubectl get pods -o wide
```

Expect output such as (both on `kind-worker`):
```
NAME    READY   STATUS    IP             NODE
pod-a   1/1     Running   10.244.2.65    kind-worker
pod-b   1/1     Running   10.244.2.137   kind-worker
```

Ping pod-b from pod-a:
```shell
kubectl exec pod-a -- ping -c 3 $(kubectl get pod pod-b -o jsonpath='{.status.podIP}')
```

Expect output such as:
```
3 packets transmitted, 3 received, 0% packet loss, time 2037ms
rtt min/avg/max/mdev = 0.078/0.158/0.269/0.080 ms
```

## 4.2 Internode connectivity: native routing vs encapsulation

Run:
```shell
cilium config view | grep -E 'routing-mode|tunnel-protocol'
```

Expect output such as (this course uses VXLAN encapsulation):
```
routing-mode        tunnel
tunnel-protocol     vxlan
```

## Clean up

Delete the cluster when you're done:
```shell
kind delete cluster
```
