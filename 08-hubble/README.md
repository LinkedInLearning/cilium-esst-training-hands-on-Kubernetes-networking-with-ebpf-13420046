# Chapter 8: Observability with Hubble

Companion files for Chapter 8. Each step lists the command to run and the output
to expect. The full walkthrough is in the course videos.

The cluster here is deliberately feature-rich (dual-stack, encapsulation, L7 and
FQDN policies) so `hubble observe` has plenty of different flows to filter on.

## 8.1 Enable Hubble Relay and the UI

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

## 8.2 Deploy the workloads and generate flows

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

## 8.3 Find flows with `hubble observe`

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
