# Chapter 7: Transparent Encryption

> ⚠️ **PLACEHOLDER** — the "Expect output" blocks below are illustrative samples and will be replaced with real captured output before release.

Companion files for Chapter 7. Each step lists the command to run and the output to expect. The full walkthrough is in the course videos.

## 7.1 Create the cluster and install Cilium

Run:
```shell
kind create cluster --config kind.yaml
cilium install --version "${CILIUM_VERSION:-1.20.2}"
cilium status --wait
```

Expect output such as:
```
    /¯¯\
 /¯¯\__/¯¯\    Cilium:             OK
 \__/¯¯\__/    Operator:           OK
 /¯¯\__/¯¯\    Envoy DaemonSet:    OK
    \__/       Encryption:         Disabled
```

## 7.2 Deploy the client and server

`client-server.yaml` pins the client and the server to different nodes, so their traffic crosses the wire between nodes:
```shell
kubectl apply -f client-server.yaml
kubectl get pods -o wide
```

Expect output such as (client and nginx land on different nodes):
```
NAME                                READY   STATUS    NODE
netshoot-client-7c9d5b8f6-abcde     1/1     Running   kind-worker
nginx-deployment-6b8c7d9f5-fghij    1/1     Running   kind-worker2
```

## 7.3 Capture pod-to-pod traffic in the clear

In one terminal, capture traffic on the kind bridge and filter for a secret header:
```shell
BRIDGE="br-$(docker network inspect kind -f '{{.Id}}' | cut -c1-12)"
docker run --rm --network host --privileged nicolaka/netshoot tcpdump -lAni "$BRIDGE" | grep "Bearer"
```

In a second terminal, send a request carrying a secret token:
```shell
kubectl exec deploy/netshoot-client -- curl -s -H "Authorization: Bearer supersecret" nginx-service
```

Expect output such as (the token is visible in cleartext on the wire):
```
Authorization: Bearer supersecret
```

## 7.4 Enable WireGuard encryption

Run:
```shell
cilium config set enable-wireguard true
cilium status --wait
cilium encrypt status
```

Expect output such as:
```
✨ Patching ConfigMap cilium-config with enable-wireguard=true...
♻️  Restarted Cilium pods

Encryption: Wireguard (3/3 nodes)
```

## 7.5 Capture again, now encrypted

Capture on the kind bridge, filtering for WireGuard (UDP 51871):
```shell
BRIDGE="br-$(docker network inspect kind -f '{{.Id}}' | cut -c1-12)"
docker run --rm --network host --privileged nicolaka/netshoot tcpdump -ni "$BRIDGE" udp and port 51871
```

In a second terminal, send the request again:
```shell
kubectl exec deploy/netshoot-client -- curl -s -H "Authorization: Bearer supersecret" nginx-service
```

Expect output such as (only encrypted WireGuard packets, the token is no longer visible):
```
IP kind-worker.51871 > kind-worker2.51871: UDP, length 148
```
