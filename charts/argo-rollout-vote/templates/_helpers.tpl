{{/*
Match vote chart labels for Service selector compatibility
*/}}
{{- define "vote.name" -}}
{{- default "vote" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "vote.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default "vote" .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "vote.labels" -}}
app.kubernetes.io/name: {{ include "vote.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
