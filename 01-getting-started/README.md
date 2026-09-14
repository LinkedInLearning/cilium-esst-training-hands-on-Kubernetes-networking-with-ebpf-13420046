# Chapter 1: Getting Started with Cilium

> ⚠️ **PLACEHOLDER** — the "Expect output" blocks below are illustrative samples and will be replaced with real captured output before release.

Companion files for Chapter 1. Each step lists the command to run and the output to expect. The full walkthrough is in the course videos.

## 1.1 Set up your Kubernetes lab environment

Run:
```shell
kind create cluster --config kind-cluster-config-no-cilium.yaml
```

Expect output such as:
```
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.31.0)
 ✓ Preparing nodes
 ✓ Writing configuration
 ✓ Starting control-plane
 ✓ Installing StorageClass
Set kubectl context to "kind-kind"
```

## 1.2 Install and validate Cilium

Run:
```shell
cilium install
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
kubectl apply -f nginx-deployment.yaml -f netshoot-client.yaml
kubectl get pods -o wide
```

Expect output such as:
```
NAME                                READY   STATUS    RESTARTS   AGE   IP             NODE
netshoot-client                     1/1     Running   0          20s   10.244.1.183   kind-worker2
nginx-deployment-74fb5f7cb9-lkzt9   1/1     Running   0          20s   10.244.2.236   kind-worker
```

Run:
```shell
kubectl exec netshoot-client -- curl -s nginx-service | grep -o "<title>.*</title>"
```

Expect output such as:
```
<title>Welcome to nginx!</title>
```

## 1.4 Secure your app with a network policy

Run:
```shell
kubectl apply -f cnp-l3l4.yaml
kubectl exec netshoot-client -- curl -m 5 -s -o /dev/null -w "%{http_code}\n" nginx-service
```

Expect output such as (the allowed client still reaches nginx on port 80):
```
200
```

## 1.5 Monitor your app with Hubble

Run:
```shell
cilium hubble enable
hubble observe --pod netshoot-client
```

Expect output such as:
```
Sep 14 09:50:01.123: default/netshoot-client -> default/nginx-deployment-... to-endpoint FORWARDED (TCP Flags: SYN)
Sep 14 09:50:01.124: default/netshoot-client <- default/nginx-deployment-... to-endpoint FORWARDED (TCP Flags: SYN, ACK)
```
