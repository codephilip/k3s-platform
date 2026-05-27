# Contributing

Thanks for considering a contribution. This repo is a small, opinionated reference, so
the bar for new features is "would this help most users provision faster?" — not "is this
useful for me?"

## Quick checklist before opening a PR

1. **Branch off `main`**, push to a topic branch, open a PR. Direct pushes to `main` are
   blocked.
2. **Keep PRs focused.** One concern per PR (e.g. Terraform changes separate from chart
   changes) — easier to review, easier to revert.
3. **Update docs in the same PR** as the change. README and quickstart drift fast.
4. **Don't add personal hostnames, emails, or tokens.** Use `example.com` / `you@example.com`
   for placeholders. CI will fail if it finds project-specific tokens.
5. **Run the local checks** before pushing:

   ```bash
   helm lint charts/example-app helm/platform-bootstrap --set acmeEmail=you@example.com
   for env in dev staging prod; do kubectl kustomize "environments/$env" >/dev/null; done
   find scripts -name '*.sh' -exec shellcheck {} +
   (cd terraform/hetzner && terraform fmt -check && terraform validate)
   (cd terraform/cloudflare && terraform fmt -check && terraform validate)
   ```

## Commit style

Conventional Commits — `feat(...)`, `fix(...)`, `chore(...)`, `docs(...)`. Keep the title
under 72 chars and explain *why* in the body when it's not obvious from the diff.

## Where to put what

- **Provisioning** (Terraform): `terraform/<module>/`
- **Cluster-wide bootstrap** (namespaces, cert-manager): `helm/platform-bootstrap/` or
  `cluster-bootstrap/` (raw Kustomize fallback)
- **App chart** (Deployment + Service + Ingress): `charts/example-app/` — fork into
  `charts/<your-app>/` for real workloads
- **Per-env Kustomize extras**: `environments/<env>/apps/`
- **Operator helpers**: `scripts/`
- **Dashboards / observability**: `observability/`

Names that are referenced from multiple files (namespaces, ClusterIssuers, the
`app-secrets` Secret name, the `platform-tools` monitoring release) are marked as
load-bearing in the README. Renaming them requires updating every consumer in the same PR.
