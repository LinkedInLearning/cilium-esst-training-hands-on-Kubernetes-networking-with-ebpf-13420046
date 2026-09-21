# Cilium Essential Training: Hands-on Kubernetes Networking with eBPF
This is the repository for the LinkedIn Learning course `Cilium Essential Training: Hands-on Kubernetes Networking with eBPF`. The full course is available from [LinkedIn Learning][lil-course-url].

![course-name-alt-text][lil-thumbnail-url]

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
- the Cilium CLI v0.20.0 and the Hubble CLI v1.19.4

The quickest way to get all of these is the included **Dev Container / GitHub Codespaces** setup: open the repo in a GitHub Codespace, or in VS Code with the Dev Containers extension, and the toolchain is installed for you.

[0]: # (Replace these placeholder URLs with actual course URLs)

[lil-course-url]: https://www.linkedin.com/learning/
[lil-thumbnail-url]: https://media.licdn.com/dms/image/v2/D4E0DAQG0eDHsyOSqTA/learning-public-crop_675_1200/B4EZVdqqdwHUAY-/0/1741033220778?e=2147483647&v=beta&t=FxUDo6FA8W8CiFROwqfZKL_mzQhYx9loYLfjN-LNjgA
