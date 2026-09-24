# Chapter 2: Cilium Architecture

Companion files for Chapter 2. This chapter is mostly narration about the Cilium
components (agent, operator, CNI plugin, eBPF, Envoy). Two lessons are hands-on,
and the commands are collected here so you can reproduce them. The full
walkthrough is in the course videos.

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

## The Cilium CNI plugin

The Cilium agent writes a CNI configuration file on each node. That file is what
tells Kubernetes to call Cilium's CNI plugin every time a pod is created or
destroyed. Check it is there:
```shell
docker exec kind-worker ls /etc/cni/net.d/
```

Expect output such as:
```
05-cilium.conflist
```

Look inside it:
```shell
docker exec kind-worker cat /etc/cni/net.d/05-cilium.conflist
```

Expect output such as (the `type: cilium-cni` line is what points Kubernetes at
Cilium's plugin binary):
```json
{
  "cniVersion": "1.0.0",
  "name": "cilium",
  "plugins": [
    {
       "type": "cilium-cni",
       "enable-debug": false,
       "log-file": "/var/run/cilium/cilium-cni.log"
    }
  ]
}
```

To see the plugin's work in detail, turn on debug logging (it is warnings-only by
default). This restarts the Cilium pods:
```shell
cilium config set debug true
```

Expect output such as:
```
✨ Patching ConfigMap cilium-config with debug=true...
♻️  Restarted Cilium pods
```
```shell
cilium status --wait
```

Confirm it took effect on the node (`enable-debug` flips to `true`):
```shell
docker exec kind-worker grep -o '"enable-debug":[^,]*' /etc/cni/net.d/05-cilium.conflist
```

Expect output such as:
```
"enable-debug": true
```

Now watch the plugin work. In the [button label=">_ Terminal"](tab-0) tab, tail
the plugin log on the node. The log file only exists once the CNI plugin has run
on this node (Cilium's own pods use host networking and don't create it), so use
`tail -F` (capital F): it waits for the file to appear instead of erroring with
"no such file or directory" when no application pod has been scheduled here yet:
```shell
docker exec -it kind-worker tail -F /var/run/cilium/cilium-cni.log
```

In a second terminal, create a pod on that node and wait for it to be ready
(the `kubectl wait` matters: `kubectl run` returns while the pod is still
Pending, and the plugin only fires once the pod is actually scheduled):
```shell
kubectl run cni-demo --image=nginx --overrides='{"spec":{"nodeName":"kind-worker"}}'
```

Expect output such as:
```
pod/cni-demo created
```
```shell
kubectl wait --for=condition=Ready pod/cni-demo --timeout=90s
```

Expect output such as:
```
pod/cni-demo condition met
```

Back in the first terminal, you will see the ADD sequence build the pod's
networking (the veth pair, the link, the routes, the endpoint):
```
level=DEBUG msg="Processing CNI ADD request"
level=DEBUG msg="Creating new linkpair"
level=DEBUG msg="Created veth pair"
level=DEBUG msg="Configuring link"
level=DEBUG msg="Adding route"
level=DEBUG msg="Endpoint successfully created"
level=DEBUG msg="CNI ADD processing complete"
```

Now delete the pod:
```shell
kubectl delete pod cni-demo
```

And you will see the DEL sequence tear it back down:
```
level=DEBUG msg="Processing CNI DEL request"
level=DEBUG msg="CNI DEL processing complete"
```

## eBPF programs and maps

Cilium loads eBPF programs at hooks in the kernel and keeps state in eBPF maps.
Inspect them with `bpftool` and `cilium-dbg`, both of which ship inside the
Cilium agent (`bpftool` is **not** on the kind node's PATH; run it through the
agent, which sees the node's own network namespace).

Deploy a pod so there is a pod veth to observe:
```shell
kubectl run demo --image=nginx --overrides='{"spec":{"nodeName":"kind-worker"}}'
```

Expect output such as:
```
pod/demo created
```
```shell
kubectl wait --for=condition=Ready pod/demo --timeout=90s
```

Expect output such as:
```
pod/demo condition met
```

List the programs attached to network interfaces:
```shell
kubectl exec -n kube-system ds/cilium -c cilium-agent -- bpftool net show
```

Expect output such as (node interfaces plus a `lxc…` program per pod veth,
`cil_from_container`, deciding what happens to every packet the pod emits):
```
eth0(11) tcx/ingress cil_from_netdev prog_id 3992 link_id 84
cilium_net(12) tcx/ingress cil_to_host prog_id 3983 link_id 83
cilium_host(13) tcx/ingress cil_to_host prog_id 3969 link_id 81
cilium_host(13) tcx/egress cil_from_host prog_id 3961 link_id 82
cilium_vxlan(16) tcx/ingress cil_from_overlay prog_id 3858 link_id 78
cilium_vxlan(16) tcx/egress cil_to_overlay prog_id 3859 link_id 79
lxc52ab95b12592(18) tcx/ingress cil_from_container prog_id 4066 link_id 93
```

Now the maps. eBPF programs are stateless; the state they read on every packet
lives in eBPF maps that the agent keeps in sync with Kubernetes. List them,
filtered to the ones named in the lesson:
```shell
kubectl exec -n kube-system ds/cilium -c cilium-agent -- cilium-dbg map list | grep -E 'cilium_lxc|cilium_ipcache|cilium_policy|cilium_lb4_services'
```

Expect output such as (`cilium_lxc` tracks local endpoints, `cilium_ipcache_v2`
maps IPs to identities cluster-wide, `cilium_policy_v3_*` holds per-endpoint
policy, `cilium_lb4_services_v2` holds service load-balancing state):
```
cilium_policy_v3_00312     10            0            true
cilium_lb4_services_v2     16            0            true
cilium_ipcache_v2          15            0            true
cilium_lxc                 4             0            true
```

## Clean up

Revert debug logging and delete the cluster:
```shell
kubectl delete pod demo --ignore-not-found
```
```shell
cilium config set debug false
```
```shell
kind delete cluster
```

Expect output such as:
```
Deleting cluster "kind" ...
Deleted nodes: ["kind-control-plane" "kind-worker" "kind-worker2"]
```
