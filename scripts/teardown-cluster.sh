#!/usr/bin/env bash
# Remove Argo CD, and optionally cert-manager + platform namespaces, so you can start clean.
# Run from repo root with KUBECONFIG set.
#
# Usage: ./scripts/teardown-cluster.sh [--cert-manager] [--namespaces] [--yes]

set -euo pipefail

REMOVE_CERT_MANAGER=false
REMOVE_NAMESPACES=false
CONFIRM_YES=false

for arg in "$@"; do
  case "$arg" in
    --cert-manager) REMOVE_CERT_MANAGER=true ;;
    --namespaces)   REMOVE_NAMESPACES=true ;;
    --yes)          CONFIRM_YES=true ;;
    -h|--help)
      cat <<USAGE
Usage: $0 [--cert-manager] [--namespaces] [--yes]
  --cert-manager  Also remove cert-manager namespace and CRDs
  --namespaces    Also remove dev-apps, staging-apps, prod-apps, observability
  --yes           Skip confirmation prompt
USAGE
      exit 0
      ;;
  esac
done

if ! kubectl cluster-info &>/dev/null; then
  echo "Error: kubectl cannot reach the cluster. Set KUBECONFIG (e.g. export KUBECONFIG=~/.kube/config)" >&2
  exit 1
fi

echo "This will remove from the current cluster:"
echo "  - Argo CD (namespace argocd + Argo CRDs)"
if "$REMOVE_CERT_MANAGER"; then
  echo "  - cert-manager (namespace cert-manager + cert-manager CRDs)"
fi
if "$REMOVE_NAMESPACES"; then
  echo "  - Namespaces: dev-apps, staging-apps, prod-apps, observability"
fi
echo ""

if ! "$CONFIRM_YES"; then
  read -r -p "Continue? [y/N] " resp
  if [[ ! "$resp" =~ ^[yY] ]]; then
    echo "Aborted."
    exit 0
  fi
fi

echo "Removing Argo CD..."
kubectl delete namespace argocd --ignore-not-found --timeout=120s || true
for crd in $(kubectl get crd -o name 2>/dev/null | grep -E 'argoproj\.io|argocd' || true); do
  echo "  Deleting CRD $crd"
  kubectl delete "$crd" --ignore-not-found --timeout=30s || true
done
echo "Argo CD removed."

if "$REMOVE_CERT_MANAGER"; then
  echo "Removing cert-manager..."
  kubectl delete namespace cert-manager --ignore-not-found --timeout=120s || true
  for crd in $(kubectl get crd -o name 2>/dev/null | grep 'cert-manager\.io' || true); do
    echo "  Deleting CRD $crd"
    kubectl delete "$crd" --ignore-not-found --timeout=30s || true
  done
  echo "cert-manager removed."
fi

if "$REMOVE_NAMESPACES"; then
  echo "Removing platform namespaces..."
  for ns in dev-apps staging-apps prod-apps observability; do
    kubectl delete namespace "$ns" --ignore-not-found --timeout=60s || true
  done
  echo "Namespaces removed."
fi

echo ""
echo "Teardown complete. Reinstall with: ./scripts/install-bootstrap-helm.sh"
