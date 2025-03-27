{{- define "mongodb-backup.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "mongodb-backup.labels" -}}
app.kubernetes.io/name: {{ include "mongodb-backup.name" . }}
helm.sh/chart: {{ include "mongodb-backup.name" . }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: Helm
{{- end -}}

{{- define "mongodb-backup.selectorLabels" -}}
app.kubernetes.io/name: {{ include "mongodb-backup.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "mongodb-backup.pvcLabels" -}}
app: {{ include "mongodb-backup.name" . }}
{{- end -}}