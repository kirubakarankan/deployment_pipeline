{{- define "canary-app.name" -}}
{{- .Release.Name -}}
{{- end -}}

{{- define "canary-app.labels" -}}
app.kubernetes.io/name: {{ include "canary-app.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{- define "canary-app.selector" -}}
app.kubernetes.io/name: {{ include "canary-app.name" . }}
{{- end -}}
