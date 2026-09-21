# Chapter 5: Service Routing Without kube-proxy

Companion files for Chapter 5. Each step lists the command to run and the output to expect. The full walkthrough is in the course videos.

## 5.1 Kubernetes Services refresher

Start on a standard cluster that still runs kindnet and kube-proxy, so we can see how Services are programmed the traditional way:
```shell
kind create cluster --config kind-cluster-config-no-cilium.yaml
kubectl apply -f nginx-deployment.yaml
kubectl get svc nginx-service
```

Expect output such as:
```
NAME            TYPE        CLUSTER-IP     PORT(S)   AGE
nginx-service   ClusterIP   10.96.21.129   80/TCP    3s
```

## 5.2 kube-proxy: role and limitations

kube-proxy programs Services as iptables rules. Create 100 services and count the rules kube-proxy has to install: each packet may walk hundreds of them.
```shell
for i in $(seq 1 100); do kubectl expose deployment nginx-deployment --port=80 --name="nginx-$i"; done
docker exec kind-worker iptables-save | grep -c KUBE
```

Expect output such as:
```
787
```

## 5.3 Replace kube-proxy with Cilium and verify

The old cluster still runs kube-proxy, so delete it and create one with no kube-proxy at all, install Cilium with kube-proxy replacement, then recreate the 100 services:
```shell
kind delete cluster
kind create cluster --config kind-no-kube-proxy.yaml
cilium install --version "${CILIUM_VERSION:-1.20.2}" --set kubeProxyReplacement=true
kubectl apply -f nginx-deployment.yaml
for i in $(seq 1 100); do kubectl expose deployment nginx-deployment --port=80 --name="nginx-$i"; done
```

Confirm no Service iptables rules remain, they live in the eBPF service map instead:
```shell
docker exec kind-worker iptables-save | grep KUBE-SEP | wc -l
kubectl -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg service list
```

Expect output such as (zero iptables Service rules, the Services now live in the eBPF map):
```
0
```
```
ID    Frontend               Service Type   Backend
1     10.96.0.10:53/TCP      ClusterIP      1 => 10.244.1.140:53/TCP (active)
                                            2 => 10.244.1.165:53/TCP (active)
4     10.96.0.1:443/TCP      ClusterIP      1 => 172.18.0.2:6443/TCP (active)
```

## 5.4 Ingress and Gateway API in Cilium

> Routes to `nginx-service` from Chapter 1.

Gateway API needs its CRDs first (Cilium does **not** install these), then the feature enabled via Helm with `--reuse-values`. The experimental channel installs every CRD Cilium's Gateway API support uses (Gateway, HTTPRoute, ReferenceGrant, GRPCRoute, TLSRoute, and more):
```shell
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.6.1/experimental-install.yaml
helm upgrade cilium cilium/cilium --version "${CILIUM_VERSION:-1.20.2}" --namespace kube-system \
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

> **Reaching the LoadBalancer IP.** The address (`172.18.255.200`) is announced on the kind Docker bridge via L2 (ARP). On **Linux** Docker, `curl` from the host reaches it directly. On **Docker Desktop** (macOS/Windows) the bridge lives inside a VM and ARP announcements are not visible from the host, so the `curl` above will time out. There, verify the route from inside the cluster instead:
> ```shell
> GWIP=$(kubectl get svc cilium-gateway-nginx-gateway -o jsonpath='{.spec.clusterIP}')
> kubectl run gwtest --image=nicolaka/netshoot --restart=Never --command -- sleep 60
> kubectl wait --for=condition=Ready pod/gwtest
> kubectl exec gwtest -- curl -s "http://$GWIP/" | grep -o "<title>.*</title>"
> kubectl delete pod gwtest
> ```

## Clean up

Delete the cluster when you're done:
```shell
kind delete cluster
```
