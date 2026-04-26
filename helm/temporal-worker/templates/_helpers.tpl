{{/*
Chart name used as the base for resource names.
*/}}
{{- define "temporal-worker.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Fully qualified app name. Includes release name to avoid collisions
when the chart is installed multiple times in the same cluster.
*/}}
{{- define "temporal-worker.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Common labels applied to every resource.
*/}}
{{- define "temporal-worker.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "temporal-worker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/component: worker
app.kubernetes.io/part-of: tessera
{{- end -}}

{{/*
Selector labels — must match between Service/Deployment and pods.
A subset of common labels (no version/managed-by, since those change between releases).
*/}}
{{- define "temporal-worker.selectorLabels" -}}
app.kubernetes.io/name: {{ include "temporal-worker.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}