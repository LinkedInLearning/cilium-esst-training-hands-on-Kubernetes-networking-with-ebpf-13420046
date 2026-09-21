# Chapter 1: Getting Started with Cilium

> ⚠️ **PLACEHOLDER** — the "Expect output" blocks below are illustrative samples and will be replaced with real captured output before release.

Companion files for Chapter 1. Each step lists the command to run and the output to expect. The full walkthrough is in the course videos.

## 1.1 Set up your Kubernetes lab environment

Run:
```shell
kind create cluster --config kind.yaml
```

Expect output such as:
```
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.36.4)
 ✓ Preparing nodes
 ✓ Writing configuration
 ✓ Starting control-plane
 ✓ Installing StorageClass
Set kubectl context to "kind-kind"
```

## 1.2 Install and validate Cilium

Run:
```shell
cilium install --version "${CILIUM_VERSION:-1.20.2}"
cilium status --wait
```

Expect output such as:
```
    /¯¯\
 /¯¯\__/¯¯\    Cilium:             OK
 \__/¯¯\__/    Operator:           OK
 /¯¯\__/¯¯\    Envoy DaemonSet:    OK
 \__/¯¯\__/    Hubble Relay:       disabled
    \__/       ClusterMesh:        disabled

DaemonSet   cilium   Desired: 3, Ready: 3/3, Available: 3/3
Containers: cilium   Running: 3
```

## 1.3 Deploy a sample application

Run:
```shell
kubectl apply -f nginx-deployment.yaml -f client.yaml
kubectl get pods -o wide
```

Expect output such as:
```
NAME                                READY   STATUS    RESTARTS   AGE   IP             NODE
client                     1/1     Running   0          20s   10.244.1.183   kind-worker2
nginx-deployment-74fb5f7cb9-lkzt9   1/1     Running   0          20s   10.244.2.236   kind-worker
```

Run:
```shell
kubectl exec client -- curl -s nginx-service | grep -o "<title>.*</title>"
```

Expect output such as:
```
<title>Welcome to nginx!</title>
```

## 1.4 Secure your app with Cilium Network Policies

Tighten access to nginx step by step: L3 (identity), then L4 (port/protocol), then L7 (HTTP path).

**L3, allow only the client by label.** Deploy a rogue client with no matching label, then apply the L3 policy:
```shell
kubectl apply -f rogue-client.yaml
kubectl apply -f cnp-l3.yaml
kubectl exec client -- curl -m 5 -s -o /dev/null -w "%{http_code}\n" nginx-service
kubectl exec rogue-client  -- curl -m 5 -s -o /dev/null -w "%{http_code}\n" nginx-service
```

Expect output such as (authorized client allowed, rogue client dropped):
```
200
000
```

**L4, restrict to TCP port 80.** ICMP is no longer allowed, so ping is dropped:
```shell
kubectl apply -f cnp-l3l4.yaml
kubectl exec client -- ping -c 3 $(kubectl get pod -l app=nginx -o jsonpath='{.items[0].status.podIP}')
```

Expect output such as:
```
3 packets transmitted, 0 received, 100% packet loss
```

**L7, allow only GET /index.html.** Other paths are denied by Cilium's Envoy proxy:
```shell
kubectl apply -f cnp-l7.yaml
kubectl exec client -- curl -s nginx-service/50x.html
kubectl exec client -- curl -s -o /dev/null -w "%{http_code}\n" nginx-service/index.html
```

Expect output such as (the non-allowed path returns Envoy's denial, the allowed path returns 200):
```
Access denied
200
```

`curl -v nginx-service/50x.html` shows the denial comes from `server: envoy` with `HTTP/1.1 403 Forbidden`.

## 1.5 Monitor your app with Hubble

Enable Hubble and confirm it is healthy:
```shell
cilium hubble enable
cilium status --wait
```

Expect output such as:
```
Hubble Relay:       OK
```

Port-forward, then observe flows for the client:
```shell
cilium hubble port-forward &
hubble observe --pod client
```

Expect output such as:
```
default/client -> default/nginx-deployment-xxxxxxxxx to-endpoint FORWARDED (TCP)
```

Filter to just dropped HTTP traffic:
```shell
hubble observe --verdict DROPPED --protocol http
```

## Clean up

Delete the cluster when you're done:
```shell
kind delete cluster
```
