#!/usr/bin/env bash
# Adopt pre-existing Kubernetes resources so a future `helm install` can manage them.
# Use when `helm upgrade` fails with "conflict with Go-http-client" or "managed-by" errors
# because the resource was applied raw (kubectl apply) before being templated by Helm.
#
# Usage:
#   ./scripts/adopt-resources-for-helm.sh <release-name> <namespace> <kind/name> [kind/name ...]
#
# Example:
#   ./scripts/adopt-resources-for-helm.sh example-app dev-apps \
#     deployment/example-app service/example-app ingress/example-app

set -euo pipefail

if [[ $# -lt 3 ]]; then
  cat >&2 <<USAGE
Usage: $0 <release-name> <namespace> <kind/name> [kind/name ...]

Example:
  $0 example-app dev-apps deployment/example-app service/example-app

Each resource is labeled / annotated so Helm will own it on the next upgrade.
USAGE
  exit 1
fi

RELEASE="$1"; shift
NS="$1"; shift

adopt() {
  local kind=$1 name=$2
  if ! kubectl get "$kind" "$name" -n "$NS" &>/dev/null; then
    echo "  Skipping $kind/$name (not found in $NS)"
    return
  fi
  echo "Adopting $kind/$name into release ${RELEASE}..."
  kubectl label "$kind" "$name" \
    app.kubernetes.io/managed-by=Helm \
    "app.kubernetes.io/instance=${RELEASE}" \
    --namespace="$NS" --overwrite >/dev/null
  kubectl annotate "$kind" "$name" \
    "meta.helm.sh/release-name=${RELEASE}" \
    "meta.helm.sh/release-namespace=${NS}" \
    --namespace="$NS" --overwrite >/dev/null
  # Claim field ownership so Helm's server-side apply doesn't conflict on the next upgrade.
  kubectl get "$kind" "$name" -n "$NS" -o yaml | \
    kubectl apply --server-side --force-conflicts --field-manager=helm -n "$NS" -f - >/dev/null
}

for res in "$@"; do
  if [[ "$res" != */* ]]; then
    echo "Error: '$res' is not of the form <kind>/<name>" >&2
    exit 1
  fi
  adopt "${res%%/*}" "${res##*/}"
done

echo "Done. Re-run your helm upgrade."
