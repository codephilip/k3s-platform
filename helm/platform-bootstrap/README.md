# platform-bootstrap Helm chart

Creates the platform namespaces and the Let's Encrypt cert-manager ClusterIssuers. Install **after** the cert-manager controller (Jetstack chart).

The wrapper script `scripts/install-bootstrap-helm.sh` installs both cert-manager and this chart for you. Use the manual install below only if you want fine-grained control.

## Install (recommended)

From repo root, with `KUBECONFIG` pointing at your k3s cluster:

```bash
ACME_EMAIL=you@example.com ./scripts/install-bootstrap-helm.sh
```

## Manual install

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager \
  -n cert-manager --create-namespace \
  --set installCRDs=true --wait

helm upgrade --install platform-bootstrap ./helm/platform-bootstrap \
  -n kube-system \
  --set acmeEmail=you@example.com \
  --wait
```

The install will fail fast if `acmeEmail` is empty.

## Values

| Value         | Description |
|---------------|-------------|
| `acmeEmail`   | **Required.** Email for Let's Encrypt (cert expiry / policy notifications). |
| `namespaces`  | List of `{name, labels}` for namespaces. Defaults: `dev-apps`, `staging-apps`, `prod-apps`, `observability`. |

## Load-bearing names

These names are referenced by other files in the repo. Renaming them requires updating consumers:

- ClusterIssuers `letsencrypt-staging` and `letsencrypt-prod` are referenced by Ingress annotations in `environments/*/apps/*-ingress.yaml`.
- Namespaces `dev-apps`, `staging-apps`, `prod-apps`, `observability` are referenced by every script in `scripts/` and by environment kustomizations.
