# Chapter 6: Network Policy

> ⚠️ **PLACEHOLDER** — the "Expect output" blocks below are illustrative samples and will be replaced with real captured output before release.

Companion files for Chapter 6. Each step lists the command to run and the output to expect. The full walkthrough is in the course videos.

> These steps assume `nginx-deployment` and `netshoot-client` from Chapter 1 are running.

## 6.1 Open by default

Before any policy, every pod can reach the app. Deploy an extra, unauthorized client:
```shell
kubectl apply -f rogue-client.yaml
kubectl exec rogue-client -- curl -m 5 -s -o /dev/null -w "%{http_code}\n" nginx-service
```

Expect output such as:
```
200
```

## 6.3 L3 and L4 policies: identity and ports

Allow only `netshoot-client` to reach nginx on TCP 80:
```shell
kubectl apply -f cnp-l3l4.yaml
kubectl exec netshoot-client -- curl -m 5 -s -o /dev/null -w "%{http_code}\n" nginx-service
kubectl exec rogue-client -- curl -m 5 -s -o /dev/null -w "%{http_code}\n" nginx-service
```

Expect output such as (authorized client allowed, rogue client dropped):
```
200
000
```

## 6.4 L7 policy: HTTP-aware enforcement

Allow only `GET /index.html`:
```shell
kubectl apply -f cnp-l7.yaml
kubectl exec netshoot-client -- curl -m 5 -s -o /dev/null -w "%{http_code}\n" nginx-service/index.html
kubectl exec netshoot-client -- curl -m 5 -s -o /dev/null -w "%{http_code}\n" nginx-service/admin
```

Expect output such as (allowed path 200, everything else denied by the L7 proxy):
```
200
403
```

## 6.5 FQDN policy: allow specific hostnames

> Policy file `cnp-fqdn.yaml` to be added. Allows egress only to named hostnames via the DNS proxy.
