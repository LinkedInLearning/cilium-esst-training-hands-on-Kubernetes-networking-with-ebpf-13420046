#!/usr/bin/env bash
# Installs the pinned course toolchain: kubectl, Helm, kind, the Cilium CLI, and
# the Hubble CLI. Versions come from the devcontainer's containerEnv block
# (single source of truth), so bump them there, not here.
set -euo pipefail

ARCH="$(uname -m)"
case "$ARCH" in
  x86_64 | amd64) ARCH=amd64 ;;
  aarch64 | arm64) ARCH=arm64 ;;
  *)
    echo "Unsupported architecture: $ARCH" >&2
    exit 1
    ;;
esac

# Defaults so the script runs reproducibly even outside the devcontainer.
# The devcontainer's containerEnv overrides these for one-place version bumps.
: "${KUBECTL_VERSION:=v1.36.4}"
: "${HELM_VERSION:=v3.22.0}"
: "${KIND_VERSION:=v0.33.0}"
: "${CILIUM_CLI_VERSION:=v0.20.0}"
: "${HUBBLE_VERSION:=v1.20.2}"
: "${CILIUM_VERSION:=1.20.2}"

# --- kubectl ---
if ! command -v kubectl >/dev/null 2>&1; then
  echo "Installing kubectl ${KUBECTL_VERSION}..."
  curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${ARCH}/kubectl"
  sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
  rm -f /tmp/kubectl
fi

# --- Helm ---
if ! command -v helm >/dev/null 2>&1; then
  echo "Installing Helm ${HELM_VERSION}..."
  curl -fsSLo /tmp/helm.tar.gz "https://get.helm.sh/helm-${HELM_VERSION}-linux-${ARCH}.tar.gz"
  tar -C /tmp -xzf /tmp/helm.tar.gz
  sudo install -m 0755 "/tmp/linux-${ARCH}/helm" /usr/local/bin/helm
  rm -rf /tmp/helm.tar.gz "/tmp/linux-${ARCH}"
fi

# --- kind ---
if ! command -v kind >/dev/null 2>&1; then
  echo "Installing kind ${KIND_VERSION}..."
  curl -fsSLo /tmp/kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-${ARCH}"
  sudo install -m 0755 /tmp/kind /usr/local/bin/kind
  rm -f /tmp/kind
fi

# --- Cilium CLI ---
if ! command -v cilium >/dev/null 2>&1; then
  echo "Installing the Cilium CLI ${CILIUM_CLI_VERSION}..."
  (
    cd /tmp
    curl -fsSL --remote-name-all "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${ARCH}.tar.gz{,.sha256sum}"
    sha256sum --check "cilium-linux-${ARCH}.tar.gz.sha256sum"
    sudo tar -C /usr/local/bin -xzf "cilium-linux-${ARCH}.tar.gz"
    rm -f "cilium-linux-${ARCH}.tar.gz" "cilium-linux-${ARCH}.tar.gz.sha256sum"
  )
fi

# --- Hubble CLI ---
if ! command -v hubble >/dev/null 2>&1; then
  echo "Installing the Hubble CLI ${HUBBLE_VERSION}..."
  (
    cd /tmp
    curl -fsSL --remote-name-all "https://github.com/cilium/hubble/releases/download/${HUBBLE_VERSION}/hubble-linux-${ARCH}.tar.gz{,.sha256sum}"
    sha256sum --check "hubble-linux-${ARCH}.tar.gz.sha256sum"
    sudo tar -C /usr/local/bin -xzf "hubble-linux-${ARCH}.tar.gz"
    rm -f "hubble-linux-${ARCH}.tar.gz" "hubble-linux-${ARCH}.tar.gz.sha256sum"
  )
fi

echo ""
echo "Toolchain ready:"
kubectl version --client 2>/dev/null | head -1
helm version --short
kind --version
cilium version --client
hubble --version
echo "Cilium data plane pinned to ${CILIUM_VERSION} (k8s node image is pinned in the kind configs)."
