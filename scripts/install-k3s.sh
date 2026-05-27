#!/usr/bin/env bash
# Install k3s on a server (provisioned via terraform/hetzner) and fetch a kubeconfig.
# Run from the repo root: ./scripts/install-k3s.sh
#
# Env vars (all optional):
#   SSH_ALIAS         SSH target ("user@host" or alias from ~/.ssh/config). Default: root@<server_ip>
#   KUBE_CONTEXT      Name written into the kubeconfig for cluster/user/context. Default: k3s
#   KUBECONFIG_OUT    Where to write the kubeconfig. Default: $HOME/.kube/config

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HETZNER_DIR="${REPO_ROOT}/terraform/hetzner"
KUBE_CONTEXT="${KUBE_CONTEXT:-k3s}"
KUBECONFIG_OUT="${KUBECONFIG_OUT:-${HOME}/.kube/config}"

if [[ ! -d "$HETZNER_DIR" ]]; then
  echo "Error: Hetzner Terraform dir not found: $HETZNER_DIR" >&2
  exit 1
fi

echo "Reading server_ip from Terraform (${HETZNER_DIR})..."
SERVER_IP="$(cd "$HETZNER_DIR" && terraform output -raw server_ip 2>/dev/null)" || true
if [[ -z "$SERVER_IP" ]]; then
  echo "Error: Could not read server_ip. Run 'terraform apply' in $HETZNER_DIR first." >&2
  exit 1
fi

default_ssh="${SSH_ALIAS:-root@${SERVER_IP}}"
echo "SSH target (alias from ~/.ssh/config or user@host). Press Enter for default: ${default_ssh}"
read -r ssh_target
ssh_target="${ssh_target:-$default_ssh}"

echo "Installing k3s on ${ssh_target}..."
ssh "$ssh_target" 'curl -sfL https://get.k3s.io | sh -'

echo "Waiting for k3s to be ready..."
sleep 10

mkdir -p "$(dirname "$KUBECONFIG_OUT")"
echo "Fetching kubeconfig to ${KUBECONFIG_OUT} (context: ${KUBE_CONTEXT})..."
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
scp "${ssh_target}:/etc/rancher/k3s/k3s.yaml" "$TMP"

# Rewrite localhost to the public IP and replace the default `default` names with $KUBE_CONTEXT
# so multiple clusters can coexist in one kubeconfig.
sed -e "s/127.0.0.1/${SERVER_IP}/" \
    -e "s/name: default/name: ${KUBE_CONTEXT}/g" \
    -e "s/cluster: default/cluster: ${KUBE_CONTEXT}/g" \
    -e "s/user: default/user: ${KUBE_CONTEXT}/g" \
    -e "s/current-context: default/current-context: ${KUBE_CONTEXT}/" \
    "$TMP" > "$KUBECONFIG_OUT"

echo ""
echo "Done. Use your cluster with:"
echo "  export KUBECONFIG=${KUBECONFIG_OUT}"
echo "  kubectl get nodes"
echo ""
