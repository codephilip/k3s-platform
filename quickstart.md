# Quickstart

A copy-paste walkthrough for going from zero to a working k3s cluster with TLS and a
deployed sample app. For reference docs, see [`README.md`](./README.md).

**Time:** ~30–45 minutes the first time, mostly waiting for DNS and certs.

> ⚠️ Don't commit `terraform.tfvars`, `terraform.tfstate*`, or `kubeconfig.yaml`. They're
> already gitignored, but be careful with `git add -f`. See the **Security** section of
> the README before pushing this repo anywhere public.

## 1. Prerequisites

- A domain in Cloudflare (`example.com`).
- A Hetzner Cloud API token.
- A Cloudflare API token with `Zone:DNS:Edit` on your zone.
- An SSH key (`~/.ssh/id_ed25519` or similar).
- Local tools: `terraform`, `kubectl`, `helm`, `ssh`, `scp`.

## 2. Provision a Hetzner server

```bash
cd terraform/hetzner
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
hcloud_token   = "your-hetzner-api-token"
ssh_public_key = "ssh-ed25519 AAAA...  you@host"   # cat ~/.ssh/id_ed25519.pub

# Optional (defaults shown):
# server_name = "k3s-node"
# server_type = "cx22"       # 2 vCPU / 4 GB. cpx21 / cx32 if you need more.
# location    = "fsn1"       # fsn1 (Falkenstein), nbg1 (Nürnberg), hel1 (Helsinki)
# image       = "ubuntu-22.04"
```

```bash
terraform init
terraform apply
# Note the server_ip output — you'll need it.
cd ../..
```

## 3. Install k3s

The helper script SSHes to the new server, runs the official k3s installer, and writes a
kubeconfig to `~/.kube/config` with context name `k3s` (override via `KUBE_CONTEXT=`):

```bash
./scripts/install-k3s.sh
```

When prompted for an SSH target, hit Enter to use `root@<server_ip>` from Terraform.

Verify:

```bash
export KUBECONFIG=~/.kube/config
kubectl get nodes        # one node, status Ready
```

## 4. Point DNS at the cluster

```bash
cd terraform/cloudflare
cp terraform.tfvars.example terraform.tfvars
```

Edit:

```hcl
cloudflare_api_token = "your-cloudflare-token"
zone_id              = "your-zone-id"          # Cloudflare dashboard → overview
domain               = "example.com"
ingress_ip           = "1.2.3.4"               # = server_ip from step 2
subdomains           = ["*.apps", "*.api"]     # creates *.apps.example.com, *.api.example.com
proxied              = false                   # true = Cloudflare proxy (orange cloud)
```

```bash
terraform init
terraform apply
cd ../..
```

DNS records typically resolve within a minute. Confirm:

```bash
dig +short test.apps.example.com    # should return your server_ip
```

## 5. Bootstrap the cluster

Installs cert-manager + namespaces + Let's Encrypt ClusterIssuers:

```bash
ACME_EMAIL=you@example.com ./scripts/install-bootstrap-helm.sh
```

Verify:

```bash
kubectl get ns                    # dev-apps, staging-apps, prod-apps, observability, cert-manager
kubectl get clusterissuer         # letsencrypt-staging, letsencrypt-prod (Ready)
```

If a ClusterIssuer shows `Ready=False`, check `kubectl describe clusterissuer
letsencrypt-staging` — usually a DNS or email issue.

## 6. Deploy the example app

Edit `charts/example-app/values-dev.yaml` and change the host:

```yaml
ingress:
  hosts:
    - host: dev.apps.example.com   # must resolve to your ingress_ip
```

Then deploy:

```bash
helm upgrade --install example-app charts/example-app \
  -n dev-apps -f charts/example-app/values-dev.yaml
```

Watch the cert provision:

```bash
kubectl -n dev-apps get certificate -w     # should reach Ready=True in 1–2 minutes
kubectl -n dev-apps get pods               # example-app pod Running
```

Open `https://dev.apps.example.com` — you'll see the nginx welcome page over a
Let's-Encrypt-issued cert (the chart uses `letsencrypt-staging` for dev, so your browser
will warn about the cert; switch to `letsencrypt-prod` for real traffic).

## 7. Install monitoring (optional)

```bash
./scripts/install-monitoring.sh
kubectl apply -k environments/dev      # also installs the starter Grafana dashboard
kubectl port-forward -n observability svc/platform-tools-grafana 3000:80
# open http://localhost:3000 — admin / admin
```

## 8. Deploy your own app

Once the example app proves the cluster works:

1. Fork `charts/example-app` (or copy it to `charts/<your-app>`).
2. Point `image.repository` at your registry, set `image.tag` to a real tag.
3. If your registry is private, create a `ghcr-pull` (or similar) Secret in each namespace
   and set `imagePullSecrets` in values.
4. Add real env vars to `values.yaml` under `env:`, or create an `app-secrets` Secret with
   `scripts/create-app-secrets-from-env.sh` and set `envFromSecret.enabled: true`.
5. Update `values-staging.yaml` and `values-prod.yaml` for the staging and prod hostnames.

## 9. Tearing down

To remove all platform workloads but keep the cluster:

```bash
./scripts/teardown-cluster.sh --cert-manager --namespaces --yes
```

To destroy the cluster entirely:

```bash
./scripts/delete-cluster.sh
```

## Where to look when things break

- **DNS not resolving:** `dig +short host.example.com` from somewhere outside Cloudflare's
  edge. Cloudflare nameserver propagation can take a few minutes the first time you
  delegate the zone.
- **Cert stuck at `Issuing`:** `kubectl describe certificate -n <ns>` and
  `kubectl describe order -n <ns>`. Common causes: DNS doesn't resolve, Let's Encrypt
  staging cert returned (browser warning is expected), email rate-limit on prod issuer.
- **Pod stuck `ImagePullBackOff`:** wrong image repo/tag in values, or missing
  `imagePullSecrets` for a private registry. `kubectl describe pod` tells you which.
- **`helm upgrade` conflicts:** if you applied resources with raw `kubectl apply` before
  using Helm, use `scripts/adopt-resources-for-helm.sh` to relabel them so Helm can take
  over.
