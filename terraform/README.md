# Terraform — DNS and optional server

Use Terraform to provision a Hetzner server and point DNS at your k3s cluster.

## Hetzner (server)

Provisions a single Hetzner Cloud server **with a firewall** that opens 22 (SSH), 80, 443
(HTTPS), and 6443 (k3s API). Install k3s yourself via `scripts/install-k3s.sh` or add a
cloud-init `user_data` script in `main.tf`.

```bash
cd terraform/hetzner
cp terraform.tfvars.example terraform.tfvars
# Set: hcloud_token, ssh_public_key.
# Override server_name / server_type / location / image if you don't like the defaults.

terraform init
terraform apply
```

Outputs:

- `server_ip` — public IP of the node. Use this as `ingress_ip` in the Cloudflare module.
- `server_name` — name of the created server.

## Cloudflare (DNS)

Creates an A record per subdomain pattern in your Cloudflare zone, all pointing at the
ingress IP. With the default `subdomains = ["*.apps", "*.api"]`, you get wildcards like
`*.apps.example.com` and `*.api.example.com` so any host in those subtrees resolves to the
cluster.

```bash
cd terraform/cloudflare
cp terraform.tfvars.example terraform.tfvars
# Set: cloudflare_api_token, zone_id, domain, ingress_ip.
# (zone_id is on the Cloudflare dashboard overview for your domain.)

terraform init
terraform apply
```

Or pass values via env vars instead of editing the tfvars file:

```bash
export CLOUDFLARE_API_TOKEN=...
export TF_VAR_zone_id=...
export TF_VAR_domain=example.com
export TF_VAR_ingress_ip=1.2.3.4
terraform apply
```

## Order of operations

1. `terraform/hetzner` — provision the server. Note `server_ip`.
2. `scripts/install-k3s.sh` — install k3s on the server and write kubeconfig.
3. `terraform/cloudflare` — point DNS at `ingress_ip` (= the `server_ip` from step 1, or your LoadBalancer IP if you replaced k3s's default Traefik service).
4. `scripts/install-bootstrap-helm.sh` — install cert-manager and the platform namespaces.
5. Deploy `charts/example-app` to verify TLS + ingress, then build your own app.

## State and secrets

`terraform.tfvars`, `terraform.tfstate`, and `terraform.tfstate.backup` are all gitignored
because they routinely contain plaintext tokens. **Never commit them.** If you want shared
state, configure a remote backend (S3, GCS, Terraform Cloud) in `main.tf` before running
`terraform init`.

The `terraform/dns/` and `terraform/networking/` directories are intentionally empty stubs
— add modules there if you need extra DNS records (MX, TXT) or private networking.
