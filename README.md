# Cilium Essential Training: Hands-on Kubernetes Networking with eBPF
This is the repository for the LinkedIn Learning course `Cilium Essential Training: Hands-on Kubernetes Networking with eBPF`. The full course is available from [LinkedIn Learning][lil-course-url].

![course-name-alt-text][lil-thumbnail-url]
## Course description
Embark on a comprehensive journey through Kubernetes networking with Cilium. Learn how to install, configure, and manage Cilium using Helm, ensuring your clusters are both scalable and secure. Find out how to enable Hubble for dynamic traffic monitoring, DNS activity comprehension, and service dependency insights through guided exercises. Focus on security by implementing least-privileged access using Cilium network policies, underpinned with strong identity-based controls. Uncover new paths in service routing without sacrificing performance, like replacing kube-proxy. With a direct application for cloud-native platforms, validate the practicality of transparent pod-to-pod encryption, securing communication seamlessly. Targeted at platform engineers, Kubernetes admins, DevOps, and SREs, this course offers insights that help you to streamline operations in Kubernetes environments.

## Learning objectives
- List common Kubernetes networking and security challenges, and explain the core use cases Cilium addresses. 
- Describe the Cilium architecture at a high level, including its main components and how they fit into a Kubernetes cluster. 
- Install Cilium on a Kubernetes cluster using Helm and validate the deployment using built-in health checks and lab-based verification steps. 
- Enable Hubble and observe real service-to-service traffic, DNS activity, drops, and dependencies using guided investigation exercises. 
- Implement least-privilege connectivity using Cilium network policies, including identity-based policies, and verify enforcement through scenario-driven traffic tests. 
- Enable transparent encryption for pod-to-pod traffic and validate that communication is encrypted without application changes. 
- Replace kube-proxy with Cilium in a lab environment and validate end-to-end service routing using a structured, kube-proxy-free exercise. 
- Troubleshoot common Kubernetes networking issues such as blocked traffic and unexpected drops using Hubble flows, policy inspection, and repeatable diagnostics.

## About these exercise files

These are the companion files for the course. Unlike some LinkedIn Learning courses, this repository is organised **one folder per chapter** rather than branch-per-video. Each chapter folder is self-contained: it ships the manifests it needs and a `README.md` you can follow from top to bottom.

## How to use it

Pick a chapter, change into its folder, and follow its `README.md`:
```shell
cd 01-getting-started
```

Every chapter's README opens with a **Setup** (create a kind cluster and install Cilium) and ends with a **Clean up** (delete the cluster), so you can start any chapter independently and tear it down when you're done.

## Chapters

- `01-getting-started` — install Cilium, deploy an app, a first network policy, a first look at Hubble
- `02-architecture` — the Cilium components (agent, operator, CNI plugin, eBPF, Envoy); mostly narration, commands run against any Cilium cluster
- `03-ipam` — IP address management: Cluster Scope and Multi-pool
- `04-datapath` — how packets move: intranode and internode connectivity
- `05-service-routing` — kube-proxy replacement, Ingress and Gateway API
- `06-network-policy` — policy anatomy, L7 (headers, hostnames, DNS) and FQDN
- `07-encryption` — transparent encryption with WireGuard
- `08-hubble` — observability with Hubble

## Requirements

The course pins **Cilium 1.20.2** and **Kubernetes 1.36**. You'll need a Linux or macOS machine with:

- Docker
- kind v0.33.0 (ships `kindest/node:v1.36.4`)
- kubectl v1.36.4
- Helm v3.22.0
- the Cilium CLI v0.20.0 and the Hubble CLI v1.20.2

The quickest way to get all of these is the included **Dev Container / GitHub Codespaces** setup: open the repo in a GitHub Codespace, or in VS Code with the Dev Containers extension, and the toolchain is installed for you.

[0]: # (Replace these placeholder URLs with actual course URLs)

[lil-course-url]: https://www.linkedin.com/learning/cilium-essential-training-hands-on-kubernetes-networking-with-ebpf-57337523/why-cilium-has-become-the-leading-cni?u=104
[lil-thumbnail-url]: https://media.licdn.com/dms/image/v2/D4D0DAQFYgQ7FxbU62Q/learning-public-crop_675_1200/B4DaF5o4KKI8AY-/0/1793042122461?e=2147483647&v=beta&t=Lak68HuoHTODFo2yZqg5GwtHT1XLt99GKZctEc-z-gM
