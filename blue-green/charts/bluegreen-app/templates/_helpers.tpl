{{- define "bluegreen-app.name" -}}
{{- .Release.Name -}}
{{- end -}}

{{- define "bluegreen-app.labels" -}}
app.kubernetes.io/name: {{ include "bluegreen-app.name" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end -}}

{{- define "bluegreen-app.selector" -}}
app.kubernetes.io/name: {{ include "bluegreen-app.name" . }}
{{- end -}}
