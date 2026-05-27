# External DNS

External DNS auto-creates DNS records in Cloudflare (or Route53, etc.) from Ingress and
Service annotations, so you don't have to add records by hand. Optional — the Cloudflare
Terraform module already handles wildcard DNS for the common case.

## Option A — Helm (no Argo CD required)

```bash
kubectl create namespace external-dns
kubectl create secret generic cloudflare-api-token \
  -n external-dns --from-literal=api-token=YOUR_CF_TOKEN

helm repo add bitnami https://charts.bitnami.com/bitnami
helm install external-dns bitnami/external-dns \
  --namespace external-dns \
  --set provider=cloudflare \
  --set env.CF_API_TOKEN_SECRET_NAME=cloudflare-api-token \
  --set env.CF_ZONE_API_TOKEN_SECRET_NAME=cloudflare-api-token
```

Then annotate your Ingress with `external-dns.alpha.kubernetes.io/hostname: app.example.com`
and external-dns will manage the record.

## Option B — Argo CD Application

If you run Argo CD, add `external-dns-application.yaml` to `kustomization.yaml` and apply
this folder. The Application installs the same Helm chart with GitOps-managed values.
