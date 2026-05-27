{{/*
Standard Helm helpers: name, fullname, labels, selectorLabels, image reference.
Keep these as-is unless you know what you're doing — they're referenced by every
template in this chart.
*/}}

{{- define "example-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "example-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "example-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "example-app.labels" -}}
helm.sh/chart: {{ include "example-app.chart" . }}
{{ include "example-app.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "example-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "example-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/* Derive TLS secret name per host if not explicitly set. */}}
{{- define "example-app.tlsSecretName" -}}
{{- $host := .host -}}
{{- $override := .root.Values.ingress.tls.secretName -}}
{{- if $override -}}
{{- $override -}}
{{- else -}}
{{- printf "%s-tls" (replace "." "-" $host) -}}
{{- end -}}
{{- end -}}
