# Install and Configure the LDAP Component

This document describes how to operate LDAP as a LOP component using the Helm chart in this repository.

## Prerequisites

- Kubernetes cluster with access via `kubectl` and `helm`
- Target namespace (examples below use `ecosystem`)
- Pull secret for `registry.cloudogu.com` (default: `ces-container-registries`)
- Global CES configuration as a ConfigMap (default name: `global-config`)
- Admin password secret (default name: `ldap-admin-credentials`)

## 1. Provide the global ConfigMap

The component reads global values via `doguctl config --global`, especially `domain`.
At minimum, `domain` must be set.

Example:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: global-config
  namespace: ecosystem
data:
  config.yaml: |
    domain: "ces.local"
```

Create:

```bash
kubectl apply -f global-config.yaml
```

## 2. Provide the admin secret

The admin password is read from a Secret (no plaintext in `values.yaml`).

Example:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ldap-admin-credentials
  namespace: ecosystem
type: Opaque
stringData:
  password: "admin"
```

Create:

```bash
kubectl apply -f ldap-admin-credentials.yaml
```

## 3. Install/Uninstall via make targets

`helm-apply` / `helm-delete` (direct Helm release):

```bash
make -f make/component.mk VERSION=<version> helm-apply
make -f make/component.mk VERSION=<version> helm-delete
```

`component-apply` / `component-delete` (component CR):

```bash
make component-apply
make component-delete
```

## 4. Configuration (`values.yaml`) Overview

| Area | Key in `values.yaml` | Required | Effect |
|---|---|---|---|
| General | `replicas` | No | Number of pod replicas in the StatefulSet. |
| Image & Pull | `global.imagePullSecrets` | Yes | Pull secret(s) for the container image. |
| Image & Pull | `image.registry` | Yes | Container registry of the LDAP image. |
| Image & Pull | `image.repository` | Yes | Repository of the LDAP image. |
| Image & Pull | `image.tag` | Yes | Image tag of the LDAP container. |
| Image & Pull | `imagePullPolicy` | Yes | Pull behavior of the Kubernetes container. |
| Service | `service.port` | Yes | LDAP service port (container/service). |
| LDAP Config | `config.password_change.notification_enabled` | No | Enables/disables password-change notifications. |
| LDAP Config | `config.password_change.check_interval_minutes` | No | Interval for checking password changes. |
| LDAP Config | `config.password_change.mail_sender_address` | No | Sender address for password-change mails. |
| LDAP Config | `config.password_change.mail_sender_name` | No | Display name of the mail sender. |
| LDAP Config | `config.password_change.mail_subject` | No | Subject of the password-change mail. |
| LDAP Config | `config.password_change.mail_text` | No | Body/template of the password-change mail. |
| LDAP Config | `config.logging.root` | No | Log level for LDAP scripts and startup logic. |
| LDAP Config | `config.user_search_size_limit` | No | Maximum result size for user searches. |
| LDAP Config | `config.max_db_size` | No | Maximum LDAP DB size (`olcDbMaxSize`). |
| LDAP Config | `config.admin_username` | No | Username of the initial admin user. |
| LDAP Config | `config.admin_member` | No | Controls admin membership in the admin group. |
| LDAP Config | `config.admin_givenname` | No | Given name of the initial admin user. |
| LDAP Config | `config.admin_surname` | No | Surname of the initial admin user. |
| LDAP Config | `config.admin_displayname` | No | Display name of the initial admin user. |
| LDAP Config | `config.admin_mail` | No | E-mail of the initial admin user. |
| LDAP Config | `config.openldap_suffix` | No | LDAP suffix, e.g. `dc=cloudogu,dc=com`. |
| Global CES Config | `globalConfig.configMapName` | Yes | Name of the global CES ConfigMap. |
| Global CES Config | `globalConfig.key` | Yes | Key in the global ConfigMap (typically `config.yaml`). |
| Admin Secret | `secrets.adminCredentialsSecretRef.name` | Yes | Name of the secret with the LDAP admin password. |
| Admin Secret | `secrets.adminCredentialsSecretRef.passwordKey` | Yes | Key in the admin secret containing the password. |
| Service Account Secrets | `secrets.serviceAccounts.cas.enabled` | No | Enables/disables the CAS service account (RW). |
| Service Account Secrets | `secrets.serviceAccounts.cas.secret.create` | No | Creates the CAS secret via Helm. |
| Service Account Secrets | `secrets.serviceAccounts.cas.secret.name` | No | Secret name for CAS credentials. |
| Service Account Secrets | `secrets.serviceAccounts.cas.secret.usernameKey` | No | Username key in the CAS secret. |
| Service Account Secrets | `secrets.serviceAccounts.cas.secret.passwordKey` | No | Password key in the CAS secret. |
| Service Account Secrets | `secrets.serviceAccounts.usermgt.enabled` | No | Enables/disables the UserMgmt service account (RW). |
| Service Account Secrets | `secrets.serviceAccounts.usermgt.secret.create` | No | Creates the UserMgmt secret via Helm. |
| Service Account Secrets | `secrets.serviceAccounts.usermgt.secret.name` | No | Secret name for UserMgmt credentials. |
| Service Account Secrets | `secrets.serviceAccounts.usermgt.secret.usernameKey` | No | Username key in the UserMgmt secret. |
| Service Account Secrets | `secrets.serviceAccounts.usermgt.secret.passwordKey` | No | Password key in the UserMgmt secret. |
| Service Account Secrets | `secrets.serviceAccounts.ldapMapper.enabled` | No | Enables/disables the LDAP mapper service account (RO). |
| Service Account Secrets | `secrets.serviceAccounts.ldapMapper.secret.create` | No | Creates the LDAP mapper secret via Helm. |
| Service Account Secrets | `secrets.serviceAccounts.ldapMapper.secret.name` | No | Secret name for LDAP mapper credentials. |
| Service Account Secrets | `secrets.serviceAccounts.ldapMapper.secret.usernameKey` | No | Username key in the LDAP mapper secret. |
| Service Account Secrets | `secrets.serviceAccounts.ldapMapper.secret.passwordKey` | No | Password key in the LDAP mapper secret. |
| Persistence | `persistence.size` | Yes | PVC size for LDAP data and configuration data. |
| Persistence | `persistence.storageClassName` | No | StorageClass for the StatefulSet PVC. |
| Security | `podSecurityContext.fsGroup` | Yes | Filesystem group on pod level. |
| Security | `securityContext.runAsUser` | Yes | Runtime UID of the LDAP container. |
| Security | `securityContext.runAsGroup` | Yes | Runtime GID of the LDAP container. |
| Security | `securityContext.runAsNonRoot` | Yes | Enforces non-root container runtime. |
| Security | `securityContext.allowPrivilegeEscalation` | Yes | Allows/disallows privilege escalation in the container. |
| Security | `securityContext.capabilities.drop` | Yes | Linux capabilities dropped in the container. |
| Resources | `resources.requests.cpu` | Recommended | CPU request of the LDAP container. |
| Resources | `resources.requests.memory` | Recommended | Memory request of the LDAP container. |
| Resources | `resources.limits.memory` | Recommended | Memory limit of the LDAP container. |

### Service Account Behavior

- If `secret.create=true`, Helm creates a secret.
- If a secret already exists, existing values are reused.
- If `username` is missing, a default username is used (`cas`, `usermgt`, `ldap-mapper`).
- If `password` is missing, a random password is generated.
- On startup, LDAP service accounts are reconciled with secret data (create/update/delete).
- If an account is disabled or secret data is missing, the corresponding LDAP service account is removed.

Note for ArgoCD/GitOps:

- For strict declarative operation without Helm `lookup`, prefer `secret.create=false` and externally managed secrets.

### Example Overrides

```yaml
globalConfig:
  configMapName: global-config
  key: config.yaml

secrets:
  adminCredentialsSecretRef:
    name: ldap-admin-credentials
    passwordKey: password
  serviceAccounts:
    cas:
      enabled: true
      secret:
        create: true
        name: lop-idp-ldap-cas-sa
        usernameKey: username
        passwordKey: password
    usermgt:
      enabled: true
      secret:
        create: true
        name: lop-idp-ldap-usermgt-sa
        usernameKey: username
        passwordKey: password
    ldapMapper:
      enabled: true
      secret:
        create: true
        name: lop-idp-ldap-ldap-mapper-sa
        usernameKey: username
        passwordKey: password
```

## 5. Uninstall

```bash
make component-delete
```

Depending on the StorageClass reclaim policy, the PVC is retained or removed automatically.
