# Chapter 3: IP Address Management

> ⚠️ **PLACEHOLDER** — the "Expect output" blocks below are illustrative samples and will be replaced with real captured output before release.

Companion files for Chapter 3. Each step lists the command to run and the output to expect. The full walkthrough is in the course videos.

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

Run:
```shell
cilium config view | grep -i ipam
```

Expect output such as:
```
ipam                          cluster-pool
```

## 3.5 Multi-pool IPAM

Install Cilium in multi-pool mode, then create two extra pools:
```shell
cilium install --values multi-pool.yaml
kubectl apply -f acme-pool.yaml -f foobar-pool.yaml
kubectl get ciliumpodippool
```

Expect output such as:
```
NAME          AGE
acme-pool     10s
default       40s
foobar-pool   10s
```

A pod requests a pool with the `ipam.cilium.io/ip-pool` annotation, and gets an IP from that pool's CIDR:
```shell
kubectl run acme-pod --image=nginx \
  --overrides='{"metadata":{"annotations":{"ipam.cilium.io/ip-pool":"acme-pool"}}}'
kubectl get pod acme-pod -o wide
```

Expect output such as (IP from the acme pool `10.20.0.0/16`):
```
NAME       READY   STATUS    IP          NODE
acme-pod   1/1     Running   10.20.0.5   kind-worker
```
