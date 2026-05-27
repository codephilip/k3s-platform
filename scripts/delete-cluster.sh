#!/usr/bin/env bash
# Destroy the Hetzner server (and firewall, SSH key) via Terraform. This deletes the cluster.
# Run from repo root.
#
# Usage: ./scripts/delete-cluster.sh [--yes]

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HETZNER_DIR="${REPO_ROOT}/terraform/hetzner"

if [[ ! -d "$HETZNER_DIR" ]]; then
  echo "Error: Hetzner Terraform dir not found: $HETZNER_DIR" >&2
  exit 1
fi

if [[ "${1:-}" != "--yes" ]]; then
  echo "This will run 'terraform destroy' in $HETZNER_DIR and delete the server (and cluster)."
  read -r -p "Continue? [y/N] " resp
  if [[ ! "$resp" =~ ^[yY] ]]; then
    echo "Aborted."
    exit 0
  fi
fi

cd "$HETZNER_DIR"
terraform destroy

KUBECONFIG_FILE="${HOME}/.kube/config"
if [[ -f "$KUBECONFIG_FILE" ]]; then
  echo "Removing $KUBECONFIG_FILE (it points at the now-deleted cluster)"
  rm -f "$KUBECONFIG_FILE"
fi

echo "Cluster (Hetzner server) deleted."
echo "If you used a custom KUBECONFIG, remove its context: kubectl config delete-context <name>"
