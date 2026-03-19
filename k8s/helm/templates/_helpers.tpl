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
{{- /* Split each lower/digit + upper boundary (`([a-z0-9])([A-Z])`) and insert `-` between `${1}` and `${2}`. */ -}}
{{- /* The replacement is applied globally, so `fooBarLongWord` becomes `foo-Bar-Long-Word` and then `foo-bar-long-word`. */ -}}
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

{{- define "ldap.lookupSecretValue" -}}
{{- $root := .root -}}
{{- $secretName := .secretName -}}
{{- $key := .key -}}
{{- $secret := lookup "v1" "Secret" $root.Release.Namespace $secretName -}}
{{- if and $secret $secret.data -}}
{{- with (index $secret.data $key) -}}
{{- . | b64dec -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "ldap.globalDomain" -}}
{{- $root := . -}}
{{- $globalConfig := lookup "v1" "ConfigMap" $root.Release.Namespace $root.Values.globalConfig.configMapName -}}
{{- $configYaml := "" -}}
{{- if and $globalConfig $globalConfig.data -}}
{{- $configYaml = default "" (index $globalConfig.data $root.Values.globalConfig.key) -}}
{{- end -}}
{{- $domain := default $root.Values.globalConfig.domain ((fromYaml $configYaml).domain) -}}
{{- required "global domain is required to render LDAP service account secrets" $domain -}}
{{- end -}}

{{- define "ldap.serviceAccountOu" -}}
{{- if eq . "rw" -}}Special Users{{- else -}}Bind Users{{- end -}}
{{- end -}}

{{- define "ldap.defaultServiceAccountBindDn" -}}
{{- $root := .root -}}
{{- $username := .username -}}
{{- $accessType := .accessType -}}
{{- $domain := include "ldap.globalDomain" $root -}}
{{- $suffix := default "dc=cloudogu,dc=com" $root.Values.config.openldap_suffix -}}
{{- $ou := include "ldap.serviceAccountOu" $accessType -}}
{{- printf "cn=%s,ou=%s,o=%s,%s" $username $ou $domain $suffix -}}
{{- end -}}

{{- define "ldap.renderServiceAccountSecret" -}}
{{- $root := .root -}}
{{- $accountKey := .accountKey -}}
{{- $accountConfig := .accountConfig -}}
{{- $defaultUsername := .defaultUsername -}}
{{- $accessType := .accessType -}}
{{- $secretName := include "ldap.serviceAccountSecretName" (list $root $accountKey $accountConfig) -}}
{{- $usernameKey := default "username" $accountConfig.secret.usernameKey -}}
{{- $passwordKey := default "password" $accountConfig.secret.passwordKey -}}
{{- $existingUsername := include "ldap.lookupSecretValue" (dict "root" $root "secretName" $secretName "key" $usernameKey) -}}
{{- $existingPassword := include "ldap.lookupSecretValue" (dict "root" $root "secretName" $secretName "key" $passwordKey) -}}
{{- $defaultBindDn := include "ldap.defaultServiceAccountBindDn" (dict "root" $root "username" $defaultUsername "accessType" $accessType) -}}
{{- $username := default $defaultBindDn $existingUsername -}}
{{- $password := default (randAlphaNum 40) $existingPassword -}}
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
