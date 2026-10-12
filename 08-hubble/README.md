# Chapter 8: Observability with Hubble

Companion files for Chapter 8. Each step lists the command to run and the output
to expect. The full walkthrough is in the course videos.

This chapter has two parts. **8.1** is a quick tour on a simple cluster: enable
Hubble, the UI, and Prometheus/Grafana metrics. **8.2** then rebuilds on a
deliberately feature-rich cluster (dual-stack, encapsulation, L7 and FQDN
policies) so `hubble observe` has plenty of different flows to filter on.

## 8.1 Enable Hubble, the UI, and metrics

Start on a simple single-stack cluster (the Getting Started scenario) and install Cilium:
```shell
kind create cluster --config kind-single-stack.yaml
```

Expect output such as:
```
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.36.4) 🖼
 ✓ Preparing nodes 📦 📦 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-kind"
```
```shell
cilium install --version "${CILIUM_VERSION:-1.20.2}"
```

Expect output such as:
```
🔮 Auto-detected Kubernetes kind: kind
ℹ️  Using Cilium version 1.20.2
🔮 Auto-detected cluster name: kind-kind
🔮 Auto-detected kube-proxy has been installed
```
```shell
cilium status --wait
```

Deploy the sample app, a client, a rogue client, and the L7 + FQDN policies:
```shell
kubectl apply -f nginx-deployment.yaml -f client.yaml -f rogue-client.yaml
```

Expect output such as:
```
deployment.apps/nginx-deployment created
service/nginx-service created
deployment.apps/client created
pod/rogue-client created
```
```shell
kubectl wait --for=condition=Available deployment/nginx-deployment deployment/client
```

Expect output such as:
```
deployment.apps/nginx-deployment condition met
deployment.apps/client condition met
```
```shell
kubectl apply -f cnp-l7.yaml -f cnp-fqdn.yaml
```

Expect output such as:
```
ciliumnetworkpolicy.cilium.io/cnp created
ciliumnetworkpolicy.cilium.io/fqdn created
```

Enable Hubble Relay and the UI:
```shell
cilium hubble enable --ui
```
```shell
cilium status --wait
```

Expect output such as:
```
Hubble Relay:       OK
```

Generate a mix of allowed, denied, HTTP and DNS traffic:
```shell
CLIENT=$(kubectl get pod -l app=client -o name)
```
```shell
kubectl exec "$CLIENT" -- curl -s -o /dev/null nginx-service/index.html
```
```shell
kubectl exec "$CLIENT" -- curl -s -o /dev/null nginx-service/50x.html
```
```shell
kubectl exec "$CLIENT" -- curl -s -o /dev/null --max-time 5 https://cilium.io
```
```shell
kubectl exec "$CLIENT" -- curl -s -o /dev/null --max-time 3 https://example.com
```
```shell
kubectl exec rogue-client -- curl -s -o /dev/null --max-time 3 nginx-service
```

Port-forward the Relay and watch the flows from the CLI:
```shell
cilium hubble port-forward &
```
```shell
hubble observe --pod client
```

Expect output such as:
```
default/client-6b47885cdd-hr5z2:50412 (ID:55620) -> default/nginx-deployment-596fc5b99-4skmc:80 (ID:17950) to-proxy FORWARDED (TCP Flags: ACK, PSH)
default/client-6b47885cdd-hr5z2:50412 (ID:55620) -> default/nginx-deployment-596fc5b99-4skmc:80 (ID:17950) http-request FORWARDED (HTTP/1.1 GET http://nginx-service/index.html)
default/client-6b47885cdd-hr5z2:50412 (ID:55620) <- default/nginx-deployment-596fc5b99-4skmc:80 (ID:17950) http-response FORWARDED (HTTP/1.1 200 2ms (GET http://nginx-service/index.html))
default/client-6b47885cdd-hr5z2:41787 (ID:55620) -> kube-system/coredns-589f44dc88-n48rd:53 (ID:37209) dns-request proxy FORWARDED (DNS Query nginx-service.default.svc.cluster.local. A)
```

Open the UI in your browser:
```shell
cilium hubble ui
```

Or port-forward it and browse to `http://localhost:12000`:
```shell
kubectl port-forward -n kube-system svc/hubble-ui 12000:80 &
```

Pick the `default` namespace, re-run the curls above, and watch the service map and flow table update live.

### Metrics with Prometheus and Grafana

Cilium and Hubble don't expose Prometheus metrics by default. Turn them on with a Helm upgrade:
```shell
helm repo add cilium https://helm.cilium.io/
```

Expect output such as:
```
"cilium" has been added to your repositories
```
```shell
helm upgrade cilium cilium/cilium --version "${CILIUM_VERSION:-1.20.2}" --namespace kube-system \
  --reuse-values \
  --set prometheus.enabled=true \
  --set operator.prometheus.enabled=true \
  --set hubble.enabled=true \
  --set hubble.metrics.enableOpenMetrics=true \
  --set 'hubble.metrics.enabled={dns,drop,tcp,flow,port-distribution,icmp,httpV2}'
```

Expect output such as:
```
Release "cilium" has been upgraded. Happy Helming!
```
```shell
kubectl -n kube-system rollout restart ds/cilium deploy/cilium-operator
```

Expect output such as:
```
daemonset.apps/cilium restarted
deployment.apps/cilium-operator restarted
```
```shell
kubectl -n kube-system rollout status ds/cilium
```

Deploy the ready-made Prometheus + Grafana stack from the Cilium docs (it ships with Cilium and Hubble dashboards pre-loaded):
```shell
kubectl apply -f https://raw.githubusercontent.com/cilium/cilium/1.20.2/examples/kubernetes/addons/prometheus/monitoring-example.yaml
```

Expect output such as:
```
namespace/cilium-monitoring created
serviceaccount/prometheus-k8s created
configmap/grafana-config created
configmap/grafana-cilium-dashboard created
configmap/grafana-cilium-operator-dashboard created
configmap/grafana-hubble-dashboard created
configmap/grafana-hubble-l7-http-metrics-by-workload created
configmap/prometheus created
clusterrole.rbac.authorization.k8s.io/prometheus created
clusterrolebinding.rbac.authorization.k8s.io/prometheus created
service/grafana created
service/prometheus created
deployment.apps/grafana created
deployment.apps/prometheus created
```
```shell
kubectl -n cilium-monitoring rollout status deploy/grafana deploy/prometheus
```

Expect output such as:
```
deployment "grafana" successfully rolled out
deployment "prometheus" successfully rolled out
```

Port-forward Grafana and open `http://localhost:3000` (the Cilium and Hubble dashboards are pre-loaded):
```shell
kubectl -n cilium-monitoring port-forward service/grafana 3000:3000 &
```

Port-forward Prometheus and open `http://localhost:9090` to query the raw metrics:
```shell
kubectl -n cilium-monitoring port-forward service/prometheus 9090:9090 &
```

## 8.2 Filter flows end-to-end on a dual-stack cluster

### Recreate the cluster and install Cilium

Delete the simple cluster and create the dual-stack one:
```shell
kind delete cluster
```

Expect output such as:
```
Deleting cluster "kind" ...
Deleted nodes: ["kind-control-plane" "kind-worker" "kind-worker2"]
```

Run:
```shell
kind create cluster --config kind.yaml
```

Expect output such as:
```
Creating cluster "kind" ...
 ✓ Ensuring node image (kindest/node:v1.36.4) 🖼
 ✓ Preparing nodes 📦 📦 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-kind"
```
```shell
helm repo add cilium https://helm.cilium.io/
```

Expect output such as:
```
"cilium" has been added to your repositories
```
```shell
helm repo update
```

Expect output such as:
```
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "cilium" chart repository
Update Complete. ⎈Happy Helming!⎈
```
```shell
helm install cilium cilium/cilium --version "${CILIUM_VERSION:-1.20.2}" \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=kind-control-plane \
  --set k8sServicePort=6443 \
  --set ipv6.enabled=true \
  --set ipam.mode=kubernetes \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true
```

Expect output such as:
```
NAME: cilium
LAST DEPLOYED: Wed Sep 17 16:00:00 2026
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
```
```shell
cilium status --wait
```

Check Relay is running (it's a Deployment, not a DaemonSet):
```shell
kubectl -n kube-system get deployment hubble-relay
```

Expect output such as:
```
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
hubble-relay   1/1     1            1           33s
```

Point the Hubble CLI at the Relay:
```shell
kubectl -n kube-system port-forward service/hubble-relay 4245:80 &
```

### Deploy the workloads and generate flows

Run:
```shell
kubectl apply -f nginx-deployment.yaml
```

Expect output such as:
```
deployment.apps/nginx-deployment created
service/nginx-service created
```
```shell
kubectl apply -f client.yaml
```

Expect output such as:
```
deployment.apps/client created
```
```shell
kubectl apply -f rogue-client.yaml
```

Expect output such as:
```
pod/rogue-client created
```
```shell
kubectl wait --for=condition=Available deployment/nginx-deployment deployment/client
```

Expect output such as:
```
deployment.apps/nginx-deployment condition met
deployment.apps/client condition met
```
```shell
kubectl apply -f cnp-l7.yaml
```

Expect output such as:
```
ciliumnetworkpolicy.cilium.io/cnp created
```
```shell
kubectl apply -f cnp-fqdn.yaml
```

Expect output such as:
```
ciliumnetworkpolicy.cilium.io/fqdn created
```

Confirm the pods received both an IPv4 and an IPv6 address:
```shell
kubectl get pods -o wide
```

Expect output such as:
```
NAME                               READY   STATUS    IP             NODE
client-6b47885cdd-5qzq2            1/1     Running   10.244.1.254   kind-worker
nginx-deployment-596fc5b99-4p8ll   1/1     Running   10.244.2.55    kind-worker2
rogue-client                       1/1     Running   10.244.2.116   kind-worker2
```
```shell
kubectl get pod -l app=nginx -o jsonpath='{.items[0].status.podIPs}'
```

Expect output such as:
```
[{"ip":"10.244.2.55"},{"ip":"fd00:10:244:2::88c4"}]
```

Generate a mix of allowed, denied, HTTP and DNS traffic:
```shell
CLIENT=$(kubectl get pod -l app=client -o name)
```
```shell
kubectl exec "$CLIENT" -- curl -s -o /dev/null nginx-service/index.html
```
```shell
kubectl exec "$CLIENT" -- curl -s -o /dev/null nginx-service/50x.html
```
```shell
kubectl exec "$CLIENT" -- curl -s -o /dev/null https://cilium.io
```
```shell
kubectl exec "$CLIENT" -- curl -s -o /dev/null --max-time 3 https://example.com
```
```shell
kubectl exec rogue-client -- curl -s -o /dev/null --max-time 3 nginx-service
```

Also send one request over IPv6. The Service is IPv4-only, so target the nginx pod's IPv6 address directly:
```shell
NGINX_V6=$(kubectl get pod -l app=nginx -o jsonpath='{.items[0].status.podIPs[1].ip}')
```
```shell
kubectl exec "$CLIENT" -- curl -s -o /dev/null -g -6 "http://[$NGINX_V6]/index.html"
```

In order: allowed by the L7 policy, denied by the L7 policy, allowed by the FQDN policy, denied by the FQDN policy, denied at L3 (the rogue client), and one allowed request over IPv6.

### Find flows with `hubble observe`

All traffic to nginx (compact output shows the trace point and verdict):
```shell
hubble observe --to-label app=nginx
```

Expect output such as:
```
default/client-6b47885cdd-5qzq2:51836 (ID:24390) -> default/nginx-deployment-596fc5b99-4p8ll:80 (ID:32885) to-overlay FORWARDED (TCP Flags: SYN)
default/client-6b47885cdd-5qzq2:51836 (ID:24390) -> default/nginx-deployment-596fc5b99-4p8ll:80 (ID:32885) http-request FORWARDED (HTTP/1.1 GET http://nginx-service/index.html)
```

Only the dropped flows:
```shell
hubble observe --verdict DROPPED
```

Only HTTP:
```shell
hubble observe --protocol http
```

Expect output such as:
```
default/client-6b47885cdd-5qzq2:51820 (ID:24390) -> default/nginx-deployment-596fc5b99-4p8ll:80 (ID:32885) http-request FORWARDED (HTTP/1.1 GET http://nginx-service/index.html)
default/client-6b47885cdd-5qzq2:51822 (ID:24390) -> default/nginx-deployment-596fc5b99-4p8ll:80 (ID:32885) http-request DROPPED (HTTP/1.1 GET http://nginx-service/50x.html)
```

Only HTTP, and only a specific method:
```shell
hubble observe --protocol http --http-method GET
```

Expect output such as:
```
default/client-6b47885cdd-5qzq2:51820 (ID:24390) -> default/nginx-deployment-596fc5b99-4p8ll:80 (ID:32885) http-request FORWARDED (HTTP/1.1 GET http://nginx-service/index.html)
default/client-6b47885cdd-5qzq2:51822 (ID:24390) -> default/nginx-deployment-596fc5b99-4p8ll:80 (ID:32885) http-request DROPPED (HTTP/1.1 GET http://nginx-service/50x.html)
```

DNS requests (the FQDN policy at work):
```shell
hubble observe --protocol dns
```

Expect output such as:
```
default/client-6b47885cdd-5qzq2:56211 (ID:24390) -> kube-system/coredns-589f44dc88-pjqrn:53 (ID:7836) dns-request proxy FORWARDED (DNS Query cilium.io. A)
default/client-6b47885cdd-5qzq2:56211 (ID:24390) <- kube-system/coredns-589f44dc88-pjqrn:53 (ID:7836) dns-response proxy FORWARDED (DNS Answer "104.198.14.52" TTL: 30 (Proxy cilium.io. A))
```

Just the overlay trace points (inter-node, encapsulated):
```shell
hubble observe --type trace:to-overlay
```

Filter on just the IPv6 flows:
```shell
hubble observe --ipv6 --from-pod client
```

Follow live, limited to the client:
```shell
hubble observe --from-label app=client -f
```

Each flow as readable key-value pairs, then the full detail as JSON:
```shell
hubble observe --to-label app=nginx --last 1 -o dict
```

Expect output such as:
```
  TIMESTAMP: Sep 21 11:44:52.631
     SOURCE: default/client-6b47885cdd-5qzq2:51836
DESTINATION: default/nginx-deployment-596fc5b99-4p8ll:80
       TYPE: to-proxy
    VERDICT: FORWARDED
    SUMMARY: TCP Flags: ACK, FIN
```
```shell
hubble observe --to-label app=nginx --last 1 -o json
```

## Clean up

Delete the cluster when you're done:
```shell
kind delete cluster
```

Expect output such as:
```
Deleting cluster "kind" ...
Deleted nodes: ["kind-control-plane" "kind-worker" "kind-worker2"]
```
