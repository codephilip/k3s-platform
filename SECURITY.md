# Security Policy

## Reporting a vulnerability

Please **do not** open public GitHub issues for security problems. Instead, use GitHub's
private vulnerability reporting:

→ <https://github.com/codephilip/k3s-platform/security/advisories/new>

Or email `philip@meiers.in` with the subject prefix `[k3s-platform security]`. Expect a
first reply within 72 hours.

## Scope

This repo is a *reference* — it provisions infrastructure with public Terraform providers
and deploys upstream Helm charts. Vulnerabilities in those upstream projects belong to
their maintainers (cert-manager, k3s, kube-prometheus-stack, etc.). Reports here should
cover:

- Issues in the manifests, charts, or scripts in this repo (e.g. an insecure default, a
  command-injection in a helper script).
- Issues with the security posture the repo guides users toward (e.g. a firewall rule
  that opens more than necessary, a misleading credential-handling instruction).

## What this repo expects from you

1. **Never commit `terraform.tfvars`, `terraform.tfstate*`, or `kubeconfig*`.** They are
   gitignored, but `git add -f` can override that. Each contains plaintext tokens.
2. **Rotate any token that ever lived in those files.** Even a transient commit can be
   pulled from a fork. Treat exposure as compromise.
3. **Use the staging Let's Encrypt issuer while iterating.** The prod issuer has aggressive
   rate limits; getting throttled there blocks all your cert issuance for a week.
4. **Pin upstream chart versions in production.** This repo intentionally floats some
   versions (cert-manager bootstrap, kube-prometheus-stack) for ease of first-time setup;
   for anything serious, pin and bump deliberately.
