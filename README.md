# k3s-Platform

**Clone, fill in five values, run four commands, get a TLS-enabled Kubernetes cluster.**

A no-frills reference for standing up a production-shaped [k3s](https://k3s.io) cluster
on [Hetzner Cloud](https://www.hetzner.com/cloud) with [Cloudflare](https://cloudflare.com)
DNS and automatic TLS via [cert-manager](https://cert-manager.io) + Let's Encrypt — all
driven by Terraform and Helm. First run takes about 30 minutes, most of which is waiting
for DNS to propagate and certs to issue.

## Stack

| Layer            | Tool                                                         | Why                                                                  |
|------------------|--------------------------------------------------------------|----------------------------------------------------------------------|
| Provisioning     | **Terraform** + Hetzner Cloud provider                       | One server, one firewall, ~€5/month. Swap providers in one file.     |
| DNS              | **Terraform** + Cloudflare provider                          | Wildcard A records, optional proxying. Free zone is enough.          |
| Cluster          | **k3s** (single-binary Kubernetes)                           | Lightweight, batteries-included, ships with Traefik ingress.         |
| Ingress          | **Traefik** (built into k3s)                                 | No extra install. Standard `ingressClassName: traefik`.              |
| TLS              | **cert-manager** + **Let's Encrypt**                         | Automatic issuance + renewal. Staging + prod ClusterIssuers ready.   |
| App packaging    | **Helm**                                                     | The `example-app` chart is your starting point.                      |
| Env layering     | **Kustomize** overlays                                       | Per-env extras (secrets, dashboards) without forking chart values.   |
| Observability    | **kube-prometheus-stack** (Prometheus + Grafana + Alertmanager) | One script, full stack in the `observability` namespace.          |

Everything above is open source. The whole repo is ~300 KB of YAML, HCL, and bash — no
hidden services, no SaaS dependencies.

## What you get

- **Provisioning** — A single Hetzner server (configurable size/location) with a firewall
  that opens only what k3s + ingress need (22, 80, 443, 6443).
- **DNS** — Wildcard A records in Cloudflare pointing at the cluster (`*.apps.example.com`,
  `*.api.example.com`, etc).
- **k3s + Traefik** — Stock k3s with its built-in Traefik ingress controller.
- **TLS** — cert-manager + Let's Encrypt with two ClusterIssuers (`letsencrypt-staging` for
  iteration, `letsencrypt-prod` for real traffic). Automatic cert issuance and renewal.
- **Three namespaces** — `dev-apps`, `staging-apps`, `prod-apps` for environment isolation.
- **Example app** — A minimal Helm chart (`charts/example-app`) you can deploy as-is to
  prove the cluster works end-to-end, then fork for your real workload.
- **Monitoring (optional)** — One command to install kube-prometheus-stack
  (Prometheus + Grafana + Alertmanager) into an `observability` namespace.
- **Helper scripts** — `install-k3s.sh`, `install-bootstrap-helm.sh`,
  `install-monitoring.sh`, `create-app-secrets-from-env.sh`, `teardown-cluster.sh`,
  `delete-cluster.sh`.

## Prerequisites

You need:

- A domain you control, managed in Cloudflare (free plan is fine).
- A Hetzner Cloud account and an API token.
- A Cloudflare API token with `Zone:DNS:Edit` permission on your zone.
- An SSH key pair (e.g. `~/.ssh/id_ed25519`).
- Local tools: `terraform` ≥ 1.5, `kubectl` ≥ 1.27, `helm` ≥ 3.12, `bash`, `ssh`, `scp`.

> **First-time? Read [`quickstart.md`](./quickstart.md)** for the same flow as a copy-paste
> tutorial. The rest of this README is the reference doc.

## End-to-end setup

```bash
# 1. Provision the server.
cd terraform/hetzner
cp terraform.tfvars.example terraform.tfvars
# Edit: set hcloud_token and ssh_public_key.
terraform init && terraform apply
SERVER_IP=$(terraform output -raw server_ip)
cd ../..

# 2. Install k3s and fetch a kubeconfig.
./scripts/install-k3s.sh
export KUBECONFIG=~/.kube/config
kubectl get nodes   # should show one node, Ready

# 3. Point DNS at the server.
cd terraform/cloudflare
cp terraform.tfvars.example terraform.tfvars
# Edit: set cloudflare_api_token, zone_id, domain, ingress_ip=$SERVER_IP.
terraform init && terraform apply
cd ../..

# 4. Bootstrap the cluster (cert-manager, namespaces, ClusterIssuers).
ACME_EMAIL=you@example.com ./scripts/install-bootstrap-helm.sh

# 5. Deploy the example app to verify TLS + ingress.
#    Edit charts/example-app/values-dev.yaml first: replace dev.example.com with a
#    hostname that resolves via the Cloudflare records you just created.
helm upgrade --install example-app charts/example-app \
  -n dev-apps -f charts/example-app/values-dev.yaml

# Watch the cert get issued. This typically takes 60–120s.
kubectl -n dev-apps describe certificate
```

That's the whole flow. Open `https://dev.example.com` in a browser; you should see the
nginx welcome page over a Let's Encrypt cert.

## Customization checklist

Before deploying anything you care about, replace every placeholder. Search the repo for
`example.com` and `you@example.com` to find them all — the canonical list:

| Where | What |
|------|------|
| `terraform/hetzner/terraform.tfvars` | `hcloud_token`, `ssh_public_key`. Optionally `server_name`, `server_type`, `location`, `image`. |
| `terraform/cloudflare/terraform.tfvars` | `cloudflare_api_token`, `zone_id`, `domain`, `ingress_ip`, `subdomains`, `proxied`. |
| `scripts/install-bootstrap-helm.sh` *(invocation)* | Pass `ACME_EMAIL=you@example.com` — a real address that receives cert-expiry mail. |
| `charts/example-app/values-dev.yaml` | `ingress.hosts[].host` → your dev hostname. `image.repository` → your registry once you move past nginx. |
| `charts/example-app/values-staging.yaml` | Same as dev, with staging hostnames. |
| `charts/example-app/values-prod.yaml` | Same, with prod hostnames. Defaults already select `letsencrypt-prod`. |
| `charts/example-app/values.yaml` | `imagePullSecrets` for private registries; `env` / `envFromSecret` if your app needs runtime config. |

If you also use the raw-Kustomize path (`kubectl apply -k cluster-bootstrap`) instead of
the Helm bootstrap, you must also edit:

- `cluster-bootstrap/cert-manager/cluster-issuer.yaml` — replace `you@example.com` with
  your real email (the Helm chart parameterizes this; the raw YAML doesn't).

## Application secrets

The example chart can inject a `Secret` named `app-secrets` as container env vars. Two
ways to create it:

1. **From a local `.env` file** (fastest):
   ```bash
   ./scripts/create-app-secrets-from-env.sh dev      # reads .env.local
   ./scripts/create-app-secrets-from-env.sh staging  # reads .env.local.staging
   ./scripts/create-app-secrets-from-env.sh prod     # reads .env.local.prod
   ```
   The generated YAML lands at `environments/<env>/apps/app-secrets.yaml` (gitignored).

2. **By hand** — copy `environments/<env>/apps/app-secrets.example.yaml` to
   `app-secrets.yaml`, fill in values, and `kubectl apply -f` it.

Either way, set `envFromSecret.enabled: true` in your chart values to mount it.

## Security

This repo's history (before genericization) contained live Cloudflare/Hetzner API tokens
in `terraform.tfvars` and `terraform.tfstate` files. **If you forked or cloned an earlier
state, you must:**

1. **Rotate the leaked tokens immediately** — Cloudflare and Hetzner consoles both have
   one-click revoke. Issue fresh tokens.
2. **Scrub the history** before any push to a public remote:
   ```bash
   # Install git-filter-repo: brew install git-filter-repo
   git filter-repo --invert-paths \
     --path terraform/cloudflare/terraform.tfvars \
     --path terraform/hetzner/terraform.tfvars \
     --path terraform/cloudflare/terraform.tfstate \
     --path terraform/cloudflare/terraform.tfstate.backup \
     --path terraform/hetzner/terraform.tfstate \
     --path terraform/hetzner/terraform.tfstate.backup \
     --path terraform/kubeconfig.yaml
   ```
3. **Verify** with `git log --all -p -- terraform/**/terraform.tfvars` — should be empty.

Going forward, `.gitignore` covers `terraform.tfvars`, `terraform.tfstate*`,
`kubeconfig*`, `.env*`, `*.pem`, `*.key`, etc. Don't `git add -f` past it.

For shared state, configure a remote backend (S3 with SSE, Terraform Cloud, GCS) in
`terraform/<module>/main.tf` before running `terraform init`. Local state files are fine
for solo use; they're a liability the moment a teammate joins.

## Repo layout

```
k3s-Platform/
├── terraform/
│   ├── hetzner/            # Provisions one Hetzner server + firewall
│   ├── cloudflare/         # DNS A records pointing at ingress_ip
│   ├── dns/                # Empty stub for extra DNS modules
│   └── networking/         # Empty stub for private networking
├── scripts/
│   ├── install-k3s.sh                 # SSH to server, install k3s, fetch kubeconfig
│   ├── install-bootstrap-helm.sh      # Install cert-manager + platform-bootstrap
│   ├── install-monitoring.sh          # Install kube-prometheus-stack
│   ├── create-app-secrets-from-env.sh # Turn a .env file into an app-secrets Secret
│   ├── adopt-resources-for-helm.sh    # Label raw resources so Helm can take them over
│   ├── teardown-cluster.sh            # Remove Argo CD / cert-manager / platform namespaces
│   └── delete-cluster.sh              # Terraform destroy the Hetzner server
├── helm/
│   └── platform-bootstrap/  # Helm chart: namespaces + Let's Encrypt ClusterIssuers
├── cluster-bootstrap/       # Kustomize fallback for the same bootstrap (less recommended)
├── charts/
│   └── example-app/         # Minimal generic chart (Deployment + Service + Ingress + HPA)
├── environments/
│   ├── dev/                 # Kustomize overlay for namespace dev-apps
│   ├── staging/             # Same for staging-apps
│   └── prod/                # Same for prod-apps
├── observability/
│   ├── grafana-dashboards/  # ConfigMaps auto-loaded by Grafana sidecar
│   ├── kube-prometheus-stack/  # Empty placeholders for additional resources
│   ├── loki/
│   ├── tempo/
│   └── otel-collector/
├── quickstart.md            # Copy-paste tutorial of the end-to-end flow
└── README.md                # This file
```

## Load-bearing names

A few names appear in multiple files and renaming one without the others will break the
setup. Treat these as constants unless you grep-and-update everywhere:

| Name | Where it's referenced |
|------|-----------------------|
| Namespaces `dev-apps`, `staging-apps`, `prod-apps`, `observability` | `helm/platform-bootstrap/values.yaml`, `cluster-bootstrap/namespaces/namespace.yaml`, all `scripts/*.sh`, every `environments/<env>/`. |
| ClusterIssuer names `letsencrypt-staging`, `letsencrypt-prod` | `helm/platform-bootstrap/templates/cluster-issuers.yaml`, `cluster-bootstrap/cert-manager/cluster-issuer.yaml`, `charts/example-app/values*.yaml` (in Ingress annotations). |
| Secret name `app-secrets` | `charts/example-app/values.yaml` (`envFromSecret.name`), `scripts/create-app-secrets-from-env.sh`, all `environments/*/apps/app-secrets.example.yaml`. |
| Monitoring release name `platform-tools` | `scripts/install-monitoring.sh`. Grafana service is `platform-tools-grafana`; if you rename, update port-forward hints. |
| Grafana dashboard label `grafana_dashboard: "1"` | `observability/grafana-dashboards/kustomization.yaml`. The Grafana sidecar in kube-prometheus-stack watches for this exact label. |

Everything else (release names, hostnames, image refs, server names) is free to change.

## Monitoring

```bash
./scripts/install-monitoring.sh
kubectl port-forward -n observability svc/platform-tools-grafana 3000:80
open http://localhost:3000   # admin / admin
```

The dev environment overlay (`kubectl apply -k environments/dev`) also creates a starter
dashboard ConfigMap that Grafana auto-loads. Add more dashboards by dropping JSON files in
`observability/grafana-dashboards/` and referencing them in the kustomization.

## Tearing down

```bash
# Remove cluster workloads (keeps the cluster):
./scripts/teardown-cluster.sh --cert-manager --namespaces --yes

# Destroy the cluster itself (Hetzner server + firewall + SSH key):
./scripts/delete-cluster.sh
```

## License

MIT-style — see the repo root if a `LICENSE` file is present. This is example
infrastructure; review it before running it for anything serious.
