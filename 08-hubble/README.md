# Chapter 8: Observability with Hubble

> ⚠️ **PLACEHOLDER** — the "Expect output" blocks below are illustrative samples
and will be replaced with real captured output before release.

Companion files for Chapter 8. Each step lists the command to run and the output
to expect. The full walkthrough is in the course videos.

The cluster here is deliberately feature-rich (dual-stack, encapsulation, L7 and
FQDN policies) so `hubble observe` has plenty of different flows to filter on.

## 8.1 Enable Hubble Relay and the UI

Run:
```shell
kind create cluster --config kind.yaml
helm repo add cilium https://helm.cilium.io/
helm repo update
helm install cilium cilium/cilium --version "${CILIUM_VERSION:-1.20.2}" \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=kind-control-plane \
  --set k8sServicePort=6443 \
  --set ipv6.enabled=true \
  --set ipam.mode=kubernetes \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true
cilium status --wait
```

Expect output such as:
```
NAME: cilium
LAST DEPLOYED: Wed Sep 17 16:00:00 2026
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
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

## 8.2 Deploy the workloads and generate flows

Run:
```shell
kubectl apply -f nginx-deployment.yaml
kubectl apply -f client.yaml
kubectl apply -f rogue-client.yaml
kubectl wait --for=condition=Available deployment/nginx-deployment deployment/client
kubectl apply -f cnp-l7.yaml
kubectl apply -f cnp-fqdn.yaml
```

Confirm the pods received both an IPv4 and an IPv6 address:
```shell
kubectl get pods -o wide
```

Expect output such as:
```
NAME                                READY   STATUS    IP                                    NODE
nginx-deployment-6d4c...            1/1     Running   10.244.1.42                           kind-worker
client-7f8b...             1/1     Running   10.244.2.17                           kind-worker2
```
```shell
kubectl get pod -l app=nginx -o jsonpath='{.items[0].status.podIPs}'
```

Expect output such as:
```
[{"ip":"10.244.1.42"},{"ip":"fd00:10:244:1::2a"}]
```

Generate a mix of allowed, denied, HTTP and DNS traffic:
```shell
CLIENT=$(kubectl get pod -l app=client -o name)
kubectl exec "$CLIENT" -- curl -s -o /dev/null nginx-service/index.html
kubectl exec "$CLIENT" -- curl -s -o /dev/null nginx-service/50x.html
kubectl exec "$CLIENT" -- curl -s -o /dev/null https://cilium.io
kubectl exec "$CLIENT" -- curl -s -o /dev/null --max-time 3 https://example.com
kubectl exec rogue-client -- curl -s -o /dev/null --max-time 3 nginx-service
```

Also send one request over IPv6. The Service is IPv4-only, so target the nginx pod's IPv6 address directly:
```shell
NGINX_V6=$(kubectl get pod -l app=nginx -o jsonpath='{.items[0].status.podIPs[1].ip}')
kubectl exec "$CLIENT" -- curl -s -o /dev/null -g -6 "http://[$NGINX_V6]/index.html"
```

In order: allowed by the L7 policy, denied by the L7 policy, allowed by the FQDN policy, denied by the FQDN policy, denied at L3 (the rogue client), and one allowed request over IPv6.

## 8.3 Find flows with `hubble observe`

All traffic to nginx (compact output shows the trace point and verdict):
```shell
hubble observe --to-label app=nginx
```

Expect output such as:
```
default/client-7f8b:41000 (ID:1234) -> default/nginx-deployment-6d4c:80 (ID:5678) to-overlay FORWARDED (TCP Flags: SYN)
default/rogue-client:40012 (ID:1111) <> default/nginx-deployment-6d4c:80 (ID:5678) Policy denied DROPPED (TCP Flags: SYN)
```

Only the dropped flows:
```shell
hubble observe --verdict DROPPED
```

Only HTTP, and only a specific method:
```shell
hubble observe --protocol http
hubble observe --protocol http --http-method GET
```

Expect output such as:
```
default/client-7f8b:41000 (ID:1234) -> default/nginx-deployment-6d4c:80 (ID:5678) http-request FORWARDED (HTTP/1.1 GET http://nginx-service/index.html)
default/client-7f8b:41002 (ID:1234) -> default/nginx-deployment-6d4c:80 (ID:5678) http-request DROPPED (HTTP/1.1 GET http://nginx-service/50x.html)
```

DNS requests (the FQDN policy at work):
```shell
hubble observe --protocol dns
```

Expect output such as:
```
default/client-7f8b:44100 (ID:1234) -> kube-system/coredns-abcd:53 (ID:104) dns-request FORWARDED (DNS Query cilium.io. A)
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
hubble observe --to-label app=nginx --last 1 -o json
```

## Clean up

Delete the cluster when you're done:
```shell
kind delete cluster
```
