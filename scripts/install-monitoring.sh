#!/usr/bin/env bash
# Install kube-prometheus-stack (Prometheus + Grafana + Alertmanager) into the
# `observability` namespace. Run from repo root with KUBECONFIG pointing at your cluster.
#
# The release name `platform-tools` is used in port-forward instructions and Grafana service
# DNS — change MONITORING_RELEASE below if you rename, but update README hints accordingly.

set -euo pipefail

MONITORING_RELEASE="${MONITORING_RELEASE:-platform-tools}"
MONITORING_NAMESPACE="${MONITORING_NAMESPACE:-observability}"

if ! command -v helm >/dev/null 2>&1; then
  echo "Error: helm is not installed or not on PATH." >&2
  exit 1
fi

if ! kubectl cluster-info >/dev/null 2>&1; then
  echo "Error: kubectl cannot reach the cluster. Set KUBECONFIG (e.g. export KUBECONFIG=~/.kube/config)." >&2
  exit 1
fi

echo "Creating/using namespace '${MONITORING_NAMESPACE}'..."
kubectl get namespace "$MONITORING_NAMESPACE" >/dev/null 2>&1 || kubectl create namespace "$MONITORING_NAMESPACE"

echo "Adding Helm repo prometheus-community..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update prometheus-community

echo "Installing kube-prometheus-stack as '${MONITORING_RELEASE}' in '${MONITORING_NAMESPACE}'..."
helm upgrade --install "$MONITORING_RELEASE" prometheus-community/kube-prometheus-stack \
  --namespace "$MONITORING_NAMESPACE" \
  --create-namespace \
  --wait --timeout 10m

echo ""
echo "Monitoring stack installed."
echo "  Namespace: ${MONITORING_NAMESPACE}"
echo "  Release:   ${MONITORING_RELEASE} (kube-prometheus-stack)"
echo ""
echo "To access Grafana (default admin/admin), port-forward:"
echo "  kubectl port-forward -n ${MONITORING_NAMESPACE} svc/${MONITORING_RELEASE}-grafana 3000:80"
echo ""
echo "Prometheus will scrape across all namespaces (dev-apps, staging-apps, prod-apps, etc)."
