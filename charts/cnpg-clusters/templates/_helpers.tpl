{{- define "cnpg-clusters.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "cnpg-clusters.backup-bucket" -}}
{{ .Values.backup.bucketPrefix }}-{{ .Values.global.awsAccountId }}
{{- end }}

{{- define "cnpg-clusters.iam-role" -}}
arn:aws:iam::{{ .Values.global.awsAccountId }}:role/{{ .Values.backup.iamRoleName }}
{{- end }}
