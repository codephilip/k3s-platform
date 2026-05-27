<!-- Short title in the PR header. Conventional Commits style is preferred (feat/fix/chore/docs). -->

## Summary

<!-- What does this PR change and why? Two or three sentences. Link to an issue if there is one. -->

## Test plan

<!-- How did you verify this works? Include exact commands you ran, expected output, anything
manual you checked. Helps the reviewer reproduce. -->

- [ ] `helm lint` clean
- [ ] `kubectl kustomize` builds (if env overlays touched)
- [ ] `terraform fmt -check && terraform validate` clean (if terraform touched)
- [ ] `shellcheck` clean (if scripts touched)
- [ ] README / quickstart updated to match new behavior

## Notes for reviewer

<!-- Anything subtle? Hidden invariants? Decisions you went back and forth on? -->
