# Grafana dashboards

ConfigMaps in this folder are loaded by Grafana's dashboard sidecar (shipped with
`kube-prometheus-stack`). The label `grafana_dashboard: "1"` (set in `kustomization.yaml`)
is what the sidecar watches for — don't rename it.

- **app-dashboard.json** — Request rate, memory, CPU, and pod status. Uses generic
  Prometheus metrics so it works for any app that exposes a `/metrics` endpoint and a
  `ServiceMonitor`. Edit the panel queries to match your service labels.

Pick this up by referencing the folder from an environment overlay (the dev overlay does
this by default). On `kubectl apply -k environments/dev`, the ConfigMap is created in the
`observability` namespace and Grafana auto-loads it.
