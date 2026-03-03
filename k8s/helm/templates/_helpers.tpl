{{- define "ldap.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ldap.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- include "ldap.name" . -}}
{{- end -}}
{{- end -}}

{{- define "ldap.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ldap.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "ldap.labels" -}}
app: ces
{{ include "ldap.selectorLabels" . }}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "ldap.expandSlashKeys" -}}
{{- $source := index . 0 -}}
{{- $target := dict -}}
{{- range $key, $value := $source }}
  {{- $parts := splitList "/" $key -}}
  {{- $cursor := $target -}}
  {{- $last := sub (len $parts) 1 -}}
  {{- range $idx, $part := $parts -}}
    {{- if eq $idx $last -}}
      {{- $_ := set $cursor $part $value -}}
    {{- else -}}
      {{- if not (hasKey $cursor $part) -}}
        {{- $_ := set $cursor $part (dict) -}}
      {{- else if not (kindIs "map" (get $cursor $part)) -}}
        {{- $_ := set $cursor $part (dict) -}}
      {{- end -}}
      {{- $cursor = get $cursor $part -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{- toYaml $target -}}
{{- end -}}
