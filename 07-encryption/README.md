# Chapter 7: Transparent Encryption

Companion files for Chapter 7. Each step lists the command to run and the output to expect. The full walkthrough is in the course videos.

## 7.1 Create the cluster and install Cilium

Run:
```shell
kind create cluster --config kind.yaml
cilium install --version "${CILIUM_VERSION:-1.20.2}"
cilium status --wait
cilium encrypt status
```

Expect output such as (encryption is off to start with; `cilium status` has no encryption line, so `cilium encrypt status` reports it):
```
    /¯¯\
 /¯¯\__/¯¯\    Cilium:             OK
 \__/¯¯\__/    Operator:           OK
 /¯¯\__/¯¯\    Envoy DaemonSet:    OK
 \__/¯¯\__/    Hubble Relay:       disabled
    \__/       ClusterMesh:        disabled

Encryption: Disabled (3/3 nodes)
```

## 7.2 Deploy the client and server

`client-server.yaml` pins the client and the server to different nodes, so their traffic crosses the wire between nodes:
```shell
kubectl apply -f client-server.yaml
kubectl get pods -o wide
```

Expect output such as (client and nginx land on different nodes):
```
NAME                               READY   STATUS    NODE
client-6b47885cdd-xrwhl            1/1     Running   kind-worker2
nginx-deployment-596fc5b99-5w8rv   1/1     Running   kind-worker
```

## 7.3 Capture pod-to-pod traffic in the clear

In one terminal, capture traffic on the kind bridge and filter for a secret header:
```shell
BRIDGE="br-$(docker network inspect kind -f '{{.Id}}' | cut -c1-12)"
docker run --rm --network host --privileged nicolaka/netshoot tcpdump -lAni "$BRIDGE" | grep "Bearer"
```

In a second terminal, send a request carrying a secret token:
```shell
kubectl exec deploy/client -- curl -s -H "Authorization: Bearer supersecret" nginx-service
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
kubectl exec deploy/client -- curl -s -H "Authorization: Bearer supersecret" nginx-service
```

Expect output such as (only encrypted WireGuard packets between the node IPs, the token is no longer visible):
```
IP 172.18.0.3.51871 > 172.18.0.2.51871: UDP, length 192
IP 172.18.0.2.51871 > 172.18.0.3.51871: UDP, length 256
```

## Clean up

Delete the cluster when you're done:
```shell
kind delete cluster
```
