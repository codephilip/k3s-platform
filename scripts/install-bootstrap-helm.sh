#!/usr/bin/env bash
# Install cert-manager (Jetstack chart) + platform-bootstrap (namespaces + ClusterIssuers).
# Run from repo root with KUBECONFIG set.
#
# Usage:
#   ACME_EMAIL=you@example.com ./scripts/install-bootstrap-helm.sh
#   ./scripts/install-bootstrap-helm.sh you@example.com
#
# Env vars:
#   ACME_EMAIL  Required. Let's Encrypt notifications email.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HELM_CHART="${REPO_ROOT}/helm/platform-bootstrap"
ACME_EMAIL="${ACME_EMAIL:-${1:-}}"

if [[ -z "$ACME_EMAIL" ]]; then
  echo "Error: ACME_EMAIL is required. Example:" >&2
  echo "  ACME_EMAIL=you@example.com $0" >&2
  exit 1
fi

if ! kubectl cluster-info &>/dev/null; then
  echo "Error: kubectl cannot reach the cluster. Set KUBECONFIG (e.g. export KUBECONFIG=~/.kube/config)" >&2
  exit 1
fi

echo "Adding Helm repo jetstack (cert-manager)..."
helm repo add jetstack https://charts.jetstack.io 2>/dev/null || true
helm repo update jetstack

echo "Installing cert-manager..."
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true \
  --wait --timeout 5m

echo "Installing platform-bootstrap (namespaces + ClusterIssuers)..."
helm upgrade --install platform-bootstrap "$HELM_CHART" \
  --namespace kube-system \
  --set acmeEmail="${ACME_EMAIL}" \
  --wait --timeout 2m

echo ""
echo "Bootstrap complete."
echo "  Namespaces:     dev-apps, staging-apps, prod-apps, observability, cert-manager"
echo "  ClusterIssuers: letsencrypt-staging, letsencrypt-prod"
echo ""
echo "Next: deploy the example app to verify TLS + ingress:"
echo "  helm upgrade --install example-app charts/example-app -n dev-apps -f charts/example-app/values-dev.yaml"
