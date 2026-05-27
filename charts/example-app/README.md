# example-app

A minimal, generic Helm chart you can deploy as-is to prove the cluster + ingress + TLS work end-to-end. Fork it for your real application.

## What it deploys

- A single `Deployment` running a public nginx image (no auth, no state) so the chart works without you publishing anything first.
- A `Service` (ClusterIP) on port 80 → container 8080.
- An `Ingress` with cert-manager annotations for Let's Encrypt TLS.
- An optional `HorizontalPodAutoscaler` (prod values turn this on).

## Deploy

After the cluster bootstrap (`scripts/install-bootstrap-helm.sh`) has run:

```bash
# dev
helm upgrade --install example-app charts/example-app \
  -n dev-apps -f charts/example-app/values-dev.yaml

# staging
helm upgrade --install example-app charts/example-app \
  -n staging-apps -f charts/example-app/values-staging.yaml

# prod
helm upgrade --install example-app charts/example-app \
  -n prod-apps -f charts/example-app/values-prod.yaml
```

The release name `example-app` is referenced by `scripts/create-app-secrets-from-env.sh` (for the restart-pods hint) — keep it consistent or override `--set fullnameOverride=`.

## Customize

The defaults point at a public nginx image and the host `app.example.com`. Before pointing real traffic at this:

1. **Image:** override `image.repository`/`image.tag` in `values-*.yaml` to your own registry. For private registries, set `imagePullSecrets`.
2. **Hosts:** replace `app.example.com` / `dev.example.com` / `staging.example.com` with your real hostnames.
3. **Issuer:** dev and staging use `letsencrypt-staging` (rate-limit-friendly, untrusted certs). Prod uses `letsencrypt-prod`.
4. **Env / secrets:** wire `app-secrets` via `envFromSecret.enabled: true`, or list literals under `env`.

## Files

| File | Purpose |
|------|---------|
| `Chart.yaml` | Chart metadata |
| `values.yaml` | Baseline defaults (all knobs documented inline) |
| `values-dev.yaml` | Dev overrides — staging issuer, small resources |
| `values-staging.yaml` | Staging overrides — staging issuer |
| `values-prod.yaml` | Prod overrides — prod issuer, autoscaling on |
| `templates/deployment.yaml` | Single-container Deployment |
| `templates/service.yaml` | ClusterIP Service |
| `templates/ingress.yaml` | Ingress (multi-host capable) |
| `templates/hpa.yaml` | HorizontalPodAutoscaler (gated on `autoscaling.enabled`) |
| `templates/_helpers.tpl` | Name/label helpers |
| `templates/NOTES.txt` | Post-install hints |
