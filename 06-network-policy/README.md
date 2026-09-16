# Chapter 6: Network Policy

> ⚠️ **PLACEHOLDER** — the "Expect output" blocks below are illustrative samples and will be replaced with real captured output before release.

Companion files for Chapter 6. Each step lists the command to run and the output to expect. The full walkthrough is in the course videos.

> The hands-on **L3 -> L4 -> L7** network-policy demo is in Chapter 1 (features-first). This chapter covers policy **anatomy**, extra L7 matches (**headers**, **hostnames**, **DNS**), and **FQDN** policies.

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
kubectl exec netshoot-client -- curl -s -o /dev/null -w "%{http_code}\n" nginx-service
kubectl exec netshoot-client -- curl -s -o /dev/null -w "%{http_code}\n" -H "X-Custom-Header: cilium-rocks" nginx-service
```

Expect output such as (missing header denied, correct header allowed):
```
403
200
```

**Match on the hostname.** Only allow requests whose Host header is `nginx.isovalent.com`:
```shell
kubectl apply -f cnp-l7-host.yaml
kubectl exec netshoot-client -- curl -s -o /dev/null -w "%{http_code}\n" -H "Host: evil.com" nginx-service
kubectl exec netshoot-client -- curl -s -o /dev/null -w "%{http_code}\n" -H "Host: nginx.isovalent.com" nginx-service
```

Expect output such as (wrong host denied, matching host allowed):
```
403
200
```

## 6.5 DNS policy: control which names a client can resolve

```shell
kubectl apply -f cnp-dns.yaml
kubectl exec netshoot-client -- curl -sI https://cilium.io. | head -n1
kubectl exec netshoot-client -- curl -s https://example.com
```

Expect output such as (the allowed name resolves and connects, the blocked name never resolves):
```
HTTP/2 200
curl: (6) Could not resolve host: example.com
```

Remove it before the FQDN demo so the two egress policies do not combine:
```shell
kubectl delete ciliumnetworkpolicy dns
```

## 6.6 FQDN policy: allow specific hostnames

Allow `netshoot-client` egress only to `cilium.io`, enforced by the DNS proxy:
```shell
kubectl apply -f cnp-fqdn.yaml
kubectl exec netshoot-client -- curl -m 5 -s -o /dev/null -w "%{http_code}\n" https://cilium.io
kubectl exec netshoot-client -- curl -m 5 -s -o /dev/null -w "%{http_code}\n" https://github.com
```

Expect output such as (the allowed FQDN succeeds, everything else is denied):
```
200
000
```
