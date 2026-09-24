# Chapter 6: Network Policy

Companion files for Chapter 6. Each step lists the command to run and the output to expect. The full walkthrough is in the course videos.

> The hands-on **L3 -> L4 -> L7** network-policy demo is in Chapter 1 (features-first). This chapter covers policy **anatomy**, extra L7 matches (**headers**, **hostnames**, **DNS**), and **FQDN** policies.

## Setup

Create a cluster, install Cilium, and deploy nginx and the client:
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

Expect output such as:
```
    /¯¯\
 /¯¯\__/¯¯\    Cilium:             OK
 \__/¯¯\__/    Operator:           OK
 /¯¯\__/¯¯\    Envoy DaemonSet:    OK
 \__/¯¯\__/    Hubble Relay:       disabled
    \__/       ClusterMesh:        disabled
```
```shell
kubectl apply -f nginx-deployment.yaml -f client.yaml
```

Expect output such as:
```
deployment.apps/nginx-deployment created
service/nginx-service created
pod/client created
```
```shell
kubectl rollout status deployment/nginx-deployment
```

Expect output such as:
```
deployment "nginx-deployment" successfully rolled out
```
```shell
kubectl wait --for=condition=Ready pod -l app=client
```

Expect output such as:
```
pod/client condition met
```

## 6.2 Anatomy of a network policy

`sample-knp.yaml` is the Kubernetes NetworkPolicy example from the Kubernetes docs (selects `role=db`, with ingress and egress rules). Read it next to a CiliumNetworkPolicy to see the differences:

- KNP uses `podSelector`; a CNP uses `endpointSelector`.
- A namespaced CNP applies only in its namespace; use `CiliumClusterwideNetworkPolicy` for cluster-wide rules.
- **Default allow / default deny:** an endpoint with no policy allows all traffic; as soon as any policy selects it, unmatched traffic is denied, including DNS.
- CNP adds `toEntities` (`cluster`, `world`, `kube-apiserver`, `ingress`) and, in Chapter 1, L7 and identity-based rules that KNP cannot express.

## 6.4 L7 beyond method and path: headers and hostnames

**Require a specific header.** Only allow requests carrying `X-Custom-Header: cilium-rocks`:
```shell
kubectl apply -f cnp-l7-headers.yaml
```

Expect output such as:
```
ciliumnetworkpolicy.cilium.io/cnp created
```

Without the header the request is denied:
```shell
kubectl exec client -- curl -s -o /dev/null -w "%{http_code}\n" nginx-service
```

Expect output such as:
```
403
```

With the header it is allowed:
```shell
kubectl exec client -- curl -s -o /dev/null -w "%{http_code}\n" -H "X-Custom-Header: cilium-rocks" nginx-service
```

Expect output such as:
```
200
```

**Match on the hostname.** Only allow requests whose Host header is `nginx.isovalent.com`:
```shell
kubectl apply -f cnp-l7-host.yaml
```

Expect output such as:
```
ciliumnetworkpolicy.cilium.io/cnp configured
```

The wrong host is denied:
```shell
kubectl exec client -- curl -s -o /dev/null -w "%{http_code}\n" -H "Host: evil.com" nginx-service
```

Expect output such as:
```
403
```

The matching host is allowed:
```shell
kubectl exec client -- curl -s -o /dev/null -w "%{http_code}\n" -H "Host: nginx.isovalent.com" nginx-service
```

Expect output such as:
```
200
```

## 6.5 DNS policy: control which names a client can resolve

```shell
kubectl apply -f cnp-dns.yaml
```

Expect output such as:
```
ciliumnetworkpolicy.cilium.io/dns created
```

The allowed name resolves and connects:
```shell
kubectl exec client -- curl -sI https://cilium.io. | head -n1
```

Expect output such as:
```
HTTP/2 200
```

The blocked name never resolves:
```shell
kubectl exec client -- curl -s https://example.com
```

Expect output such as:
```
curl: (6) Could not resolve host: example.com
```

Remove it before the FQDN demo so the two egress policies do not combine:
```shell
kubectl delete ciliumnetworkpolicy dns
```

Expect output such as:
```
ciliumnetworkpolicy.cilium.io "dns" deleted from default namespace
```

## 6.6 FQDN policy: allow specific hostnames

Allow `client` egress only to `cilium.io`, enforced by the DNS proxy:
```shell
kubectl apply -f cnp-fqdn.yaml
```

Expect output such as:
```
ciliumnetworkpolicy.cilium.io/fqdn created
```

The allowed FQDN succeeds:
```shell
kubectl exec client -- curl -m 5 -s -o /dev/null -w "%{http_code}\n" https://cilium.io
```

Expect output such as:
```
200
```

Everything else is denied:
```shell
kubectl exec client -- curl -m 5 -s -o /dev/null -w "%{http_code}\n" https://github.com
```

Expect output such as:
```
000
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
