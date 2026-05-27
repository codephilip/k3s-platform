#!/usr/bin/env bash
# Generate a Kubernetes Secret named `app-secrets` from a local .env file and apply it.
#
# Usage:
#   ./scripts/create-app-secrets-from-env.sh           # dev (default)
#   ./scripts/create-app-secrets-from-env.sh dev
#   ./scripts/create-app-secrets-from-env.sh staging
#   ./scripts/create-app-secrets-from-env.sh prod
#
# Inputs per environment:
#   dev      reads .env.local           → namespace dev-apps
#   staging  reads .env.local.staging   → namespace staging-apps
#   prod     reads .env.local.prod      → namespace prod-apps
#
# The secret name `app-secrets` and the namespace names (`*-apps`) are referenced by:
#   - Helm chart values (charts/example-app/values.yaml `envFromSecret.name`)
#   - environment overlays (environments/*/apps/)
# Rename only if you update those consumers too.
#
# Env vars:
#   RELEASE_NAME   Used to print rollout-restart hints. Default: example-app
#
# The generated YAML is written under environments/<env>/apps/app-secrets.yaml. That path
# is gitignored — keep it out of git.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENVIRONMENT="${1:-dev}"
RELEASE_NAME="${RELEASE_NAME:-example-app}"
SECRET_NAME="app-secrets"

case "$ENVIRONMENT" in
  dev)
    ENV_FILE="${REPO_ROOT}/.env.local"
    NAMESPACE="dev-apps"
    SECRETS_FILE="${REPO_ROOT}/environments/dev/apps/app-secrets.yaml"
    ;;
  staging)
    ENV_FILE="${REPO_ROOT}/.env.local.staging"
    NAMESPACE="staging-apps"
    SECRETS_FILE="${REPO_ROOT}/environments/staging/apps/app-secrets.yaml"
    ;;
  prod|production)
    ENV_FILE="${REPO_ROOT}/.env.local.prod"
    NAMESPACE="prod-apps"
    SECRETS_FILE="${REPO_ROOT}/environments/prod/apps/app-secrets.yaml"
    ;;
  *)
    echo "Unknown environment: $ENVIRONMENT" >&2
    echo "Usage: $0 [dev|staging|prod]" >&2
    exit 1
    ;;
esac

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Error: env file not found at $ENV_FILE" >&2
  echo "Create it with KEY=VALUE lines (one per line) and rerun." >&2
  exit 1
fi

FILTERED="$(mktemp)"
trap 'rm -f "$FILTERED"' EXIT
grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$ENV_FILE" > "$FILTERED" || true

if [[ ! -s "$FILTERED" ]]; then
  echo "Error: no valid KEY=VALUE lines found in $ENV_FILE" >&2
  exit 1
fi

mkdir -p "$(dirname "$SECRETS_FILE")"
echo "Writing $SECRETS_FILE from $ENV_FILE..."
kubectl create secret generic "$SECRET_NAME" \
  --from-env-file="$FILTERED" \
  -n "$NAMESPACE" \
  --dry-run=client -o yaml > "$SECRETS_FILE"

echo "Applying to cluster..."
kubectl apply -f "$SECRETS_FILE"

echo ""
echo "Done. Restart pods in namespace ${NAMESPACE} to pick up changes:"
echo "  kubectl rollout restart deployment ${RELEASE_NAME} -n ${NAMESPACE}"
