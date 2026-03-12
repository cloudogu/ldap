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

{{- define "ldap.kebab" -}}
{{- regexReplaceAll "([a-z0-9])([A-Z])" . "${1}-${2}" | lower -}}
{{- end -}}

{{- define "ldap.serviceAccountSecretName" -}}
{{- $root := index . 0 -}}
{{- $accountKey := index . 1 -}}
{{- $accountConfig := index . 2 -}}
{{- if $accountConfig.secret.name -}}
{{- $accountConfig.secret.name -}}
{{- else -}}
{{- printf "%s-%s-sa" (include "ldap.fullname" $root) (include "ldap.kebab" $accountKey) -}}
{{- end -}}
{{- end -}}

{{- define "ldap.initialAdminPasswordSecretName" -}}
{{- $root := . -}}
{{- if $root.Values.secrets.initialAdminPasswordSecretRef.name -}}
{{- $root.Values.secrets.initialAdminPasswordSecretRef.name -}}
{{- else -}}
{{- printf "%s-initial-admin-password" (include "ldap.fullname" $root) -}}
{{- end -}}
{{- end -}}

{{- define "ldap.renderServiceAccountSecret" -}}
{{- $root := .root -}}
{{- $accountKey := .accountKey -}}
{{- $accountConfig := .accountConfig -}}
{{- $defaultUsername := .defaultUsername -}}
{{- $secretName := include "ldap.serviceAccountSecretName" (list $root $accountKey $accountConfig) -}}
{{- $usernameKey := default "username" $accountConfig.secret.usernameKey -}}
{{- $passwordKey := default "password" $accountConfig.secret.passwordKey -}}
{{- $existingSecret := lookup "v1" "Secret" $root.Release.Namespace $secretName -}}
{{- $existingUsername := dict "value" "" -}}
{{- $existingPassword := dict "value" "" -}}
{{- if and $existingSecret $existingSecret.data -}}
{{- with (index $existingSecret.data $usernameKey) }}{{- $_ := set $existingUsername "value" (. | b64dec) -}}{{- end -}}
{{- with (index $existingSecret.data $passwordKey) }}{{- $_ := set $existingPassword "value" (. | b64dec) -}}{{- end -}}
{{- end -}}
{{- $username := default $defaultUsername (index $existingUsername "value") -}}
{{- $password := default (randAlphaNum 40) (index $existingPassword "value") -}}
apiVersion: v1
kind: Secret
metadata:
  name: {{ $secretName }}
  labels:
    {{- include "ldap.labels" $root | nindent 4 }}
type: Opaque
data:
  {{ $usernameKey | quote }}: {{ $username | b64enc | quote }}
  {{ $passwordKey | quote }}: {{ $password | b64enc | quote }}
{{- end -}}
