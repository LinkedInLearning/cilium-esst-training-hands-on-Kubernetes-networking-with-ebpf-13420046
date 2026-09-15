# Chapter 5: Service Routing Without kube-proxy

> ⚠️ **PLACEHOLDER** — the "Expect output" blocks below are illustrative samples and will be replaced with real captured output before release.

Companion files for Chapter 5. Each step lists the command to run and the output to expect. The full walkthrough is in the course videos.

## 5.1 Kubernetes Services refresher

Run:
```shell
kubectl apply -f nginx-deployment.yaml
kubectl get svc nginx-service
```

Expect output such as:
```
NAME            TYPE        CLUSTER-IP     PORT(S)   AGE
nginx-service   ClusterIP   10.96.88.207   80/TCP    5s
```

## 5.2 kube-proxy: role and limitations

A non-Cilium cluster (kindnet + kube-proxy) programs Services as iptables rules. With ~100 services that is hundreds of rules to walk per packet:
```shell
kind create cluster --config kind-cluster-config-no-cilium.yaml
docker exec kind-worker iptables-save | grep -c KUBE
```

Expect output such as:
```
400
```

## 5.3 Replace kube-proxy with Cilium and verify

Create a cluster with no kube-proxy, install Cilium with kube-proxy replacement, then create 100 services:
```shell
kind create cluster --config kind-no-kube-proxy.yaml
cilium install --version "${CILIUM_VERSION:-1.20.1}" --set kubeProxyReplacement=true
kubectl apply -f nginx-deployment.yaml
for i in $(seq 1 100); do kubectl expose deployment nginx-deployment --port=80 --name="nginx-$i"; done
```

Confirm no Service iptables rules remain, they live in the eBPF service map instead:
```shell
docker exec kind-worker iptables-save | grep KUBE-SEP | wc -l
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg service list
```

Expect output such as (zero iptables Service rules):
```
0
```

## 5.4 Ingress and Gateway API in Cilium

> Routes to `nginx-service` from Chapter 1.

Gateway API needs its CRDs first (Cilium does **not** install these), then the feature enabled via Helm with `--reuse-values`:
```shell
kubectl apply --server-side -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.6.1/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
# plus gatewayclasses, httproutes, referencegrants, grpcroutes, backendtlspolicies, tlsroutes
helm upgrade cilium cilium/cilium --version "${CILIUM_VERSION:-1.20.1}" --namespace kube-system \
  --reuse-values --set kubeProxyReplacement=true --set gatewayAPI.enabled=true
kubectl -n kube-system rollout restart deployment/cilium-operator ds/cilium
```

Create the LB IP pool, L2 announcement, Gateway and route, then reach it:
```shell
kubectl apply -f pool.yaml -f l2policy.yaml -f basic-gateway.yaml -f basic-http-route.yaml
kubectl get gateway nginx-gateway
curl -m5 -s http://172.18.255.200/ | grep -o "<title>.*</title>"
```

Expect output such as:
```
NAME            CLASS    ADDRESS          PROGRAMMED   AGE
nginx-gateway   cilium   172.18.255.200   True         20s
<title>Welcome to nginx!</title>
```
