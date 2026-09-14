# Chapter 5: Service Routing Without kube-proxy

> ⚠️ **PLACEHOLDER** — the "Expect output" blocks below are illustrative samples and will be replaced with real captured output before release.

Companion files for Chapter 5. Each step lists the command to run and the output to expect. The full walkthrough is in the course videos.

## 5.1 Kubernetes Services refresher

Run:
```shell
kubectl apply -f httpd-deployment.yaml -f httpd-service.yaml
kubectl get svc httpd
```

Expect output such as:
```
NAME    TYPE        CLUSTER-IP      PORT(S)   AGE
httpd   ClusterIP   10.96.181.20    80/TCP    5s
```

## 5.3 Replace kube-proxy with Cilium and verify

Create a cluster without kube-proxy, then install Cilium with kube-proxy replacement:
```shell
kind create cluster --config kind-no-kube-proxy.yaml
cilium install --set kubeProxyReplacement=true
```

Confirm there is no kube-proxy DaemonSet and no Service iptables rules:
```shell
kubectl -n kube-system get ds kube-proxy
docker exec kind-worker iptables-save | grep -c KUBE-SVC
```

Expect output such as:
```
Error from server (NotFound): daemonsets.apps "kube-proxy" not found
0
```

Inspect the eBPF service map that replaced them:
```shell
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg bpf lb list
```

Expect output such as:
```
SERVICE ADDRESS      BACKEND ADDRESS (REVNAT_ID) (SLOT)
10.96.181.20:80/TCP  10.244.1.20:80/TCP (12) (1)
```

## 5.4 Ingress and Gateway API in Cilium

> Targets `nginx-service` from Chapter 1, and requires L2 announcements enabled so the Gateway's LoadBalancer IP is reachable.

Run:
```shell
kubectl apply -f pool.yaml -f l2policy.yaml -f basic-gateway.yaml -f basic-http-route.yaml
kubectl get gateway nginx-gateway
```

Expect output such as:
```
NAME            CLASS    ADDRESS          PROGRAMMED   AGE
nginx-gateway   cilium   172.18.255.200   True         20s
```

Curl the Gateway address:
```shell
curl -s http://172.18.255.200/ | grep -o "<title>.*</title>"
```

Expect output such as:
```
<title>Welcome to nginx!</title>
```
