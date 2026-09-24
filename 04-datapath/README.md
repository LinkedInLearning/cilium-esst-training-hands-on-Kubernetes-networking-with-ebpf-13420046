# Chapter 4: Datapath

Companion files for Chapter 4. Each step lists the command to run and the output to expect. The full walkthrough is in the course videos.

## Setup

Create a cluster and install Cilium:
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

## 4.1 Intranode connectivity

Deploy two pods pinned to the same node:
```shell
kubectl apply -f intra-node-example.yaml
```

Expect output such as:
```
pod/pod-a created
pod/pod-b created
```
```shell
kubectl get pods -o wide
```

Expect output such as (both on `kind-worker`):
```
NAME    READY   STATUS    IP             NODE
pod-a   1/1     Running   10.244.2.65    kind-worker
pod-b   1/1     Running   10.244.2.137   kind-worker
```

Ping pod-b from pod-a:
```shell
kubectl exec pod-a -- ping -c 3 $(kubectl get pod pod-b -o jsonpath='{.status.podIP}')
```

Expect output such as:
```
3 packets transmitted, 3 received, 0% packet loss, time 2037ms
rtt min/avg/max/mdev = 0.078/0.158/0.269/0.080 ms
```

## 4.2 Internode connectivity: native routing vs encapsulation

When a pod talks to a pod on another node, the source node has to know where the destination PodCIDR lives. Cilium offers two broad approaches: **encapsulation** (wrap the pod packet inside a tunnel between nodes) and **native routing** (route it like any other packet on the host network). A node's routing table shows the difference.

**Encapsulation (VXLAN), the course default.** The cluster you installed in Setup uses VXLAN. Check the mode:
```shell
cilium config view | grep -E 'routing-mode|tunnel-protocol'
```

Expect output such as:
```
routing-mode        tunnel
tunnel-protocol     vxlan
```

Look at how the worker routes the other nodes' PodCIDRs. Every remote range points at `cilium_host`, the entry point to the tunnel:
```shell
docker exec kind-worker ip route | grep 10.244
```

Expect output such as (all remote PodCIDRs go via `cilium_host`):
```
10.244.0.0/24 via 10.244.2.73 dev cilium_host proto kernel src 10.244.2.73 mtu 65470
10.244.1.0/24 via 10.244.2.73 dev cilium_host proto kernel src 10.244.2.73 mtu 65470
10.244.2.0/24 via 10.244.2.73 dev cilium_host proto kernel src 10.244.2.73
```

The tunnel interface itself is `cilium_vxlan` (VXLAN on UDP port 8472):
```shell
docker exec kind-worker ip -d addr show cilium_vxlan
```

Expect output such as:
```
14: cilium_vxlan: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 65520 qdisc noqueue state UNKNOWN group default
    link/ether 7e:8b:54:3f:2e:6c brd ff:ff:ff:ff:ff:ff
    vxlan id 0 srcport 0 0 dstport 8472 ttl auto ageing 300 ...
```

**Native routing.** Now install Cilium in native routing mode with `autoDirectNodeRoutes`, which makes each node install direct routes to every other node's PodCIDR. It works on kind because all nodes share one L2 network (the Docker bridge). Start from a fresh cluster:
```shell
kind delete cluster
```

Expect output such as:
```
Deleting cluster "kind" ...
Deleted nodes: ["kind-control-plane" "kind-worker" "kind-worker2"]
```
```shell
kind create cluster --config kind.yaml
```
```shell
cilium install --version "${CILIUM_VERSION:-1.20.2}" --set routingMode=native --set autoDirectNodeRoutes=true --set ipv4NativeRoutingCIDR=10.244.0.0/16
```
```shell
cilium status --wait
```

Confirm the mode:
```shell
cilium config view | grep -E 'routing-mode|auto-direct-node-routes|ipv4-native-routing-cidr'
```

Expect output such as:
```
auto-direct-node-routes                           true
ipv4-native-routing-cidr                          10.244.0.0/16
routing-mode                                      native
```

Look at the routes now. The other nodes' PodCIDRs point straight at each node's real IP on `eth0`, not through a tunnel (only the local range still uses `cilium_host`):
```shell
docker exec kind-worker ip route | grep 10.244
```

Expect output such as (remote PodCIDRs via the node IPs on `eth0`):
```
10.244.0.0/24 via 172.18.0.3 dev eth0 proto kernel
10.244.1.0/24 via 10.244.1.206 dev cilium_host proto kernel src 10.244.1.206
10.244.2.0/24 via 172.18.0.2 dev eth0 proto kernel
```

That is the whole difference: in encapsulation every remote route goes through `cilium_host` and out the VXLAN tunnel; in native routing the node routes directly to the destination node's IP on the shared network.

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
