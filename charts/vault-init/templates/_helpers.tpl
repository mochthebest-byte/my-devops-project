{{- define "vault-init.name" -}}
{{- default "vault-init" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "vault-init.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default "vault-init" .Values.nameOverride }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "vault-init.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "vault-init.labels" -}}
helm.sh/chart: {{ include "vault-init.chart" . }}
app.kubernetes.io/name: {{ include "vault-init.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
