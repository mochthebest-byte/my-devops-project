{{/*
Match vote chart labels for Service selector compatibility
The Service voting-app-vote uses instance: voting-app.
Override instance via helm values: global.releaseNameOverride="voting-app"
*/}}
{{- define "vote.name" -}}
{{- default "vote" .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "vote.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default "vote" .Values.nameOverride }}
{{- $release := default .Release.Name .Values.global.releaseNameOverride }}
{{- if contains $name $release }}
{{- $release | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" $release $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{- define "vote.instance" -}}
{{- default .Release.Name .Values.global.releaseNameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "vote.rolloutName" -}}
{{- printf "%s-rollout" (include "vote.fullname" .) | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "vote.labels" -}}
app.kubernetes.io/name: {{ include "vote.name" . }}
app.kubernetes.io/instance: {{ include "vote.instance" . }}
{{- end }}
