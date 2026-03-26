# LDAP-Komponente installieren und konfigurieren

Dieses Dokument beschreibt den Betrieb von LDAP als LOP-Komponente über das Helm-Chart in diesem Repository.

## Voraussetzungen

- Kubernetes-Cluster mit Zugriff per `kubectl` und `helm`
- Ziel-Namespace (Beispiele unten verwenden `ecosystem`)
- Pull-Secret für `registry.cloudogu.com` (Standard: `ces-container-registries`)
- Globale CES-Konfiguration als ConfigMap (Standardname: `global-config`)
- Optional: Secret für das initiale Admin-Passwort

## 1. Globale ConfigMap bereitstellen

Die Komponente liest globale Werte über `doguctl config --global`, insbesondere `domain`.
Mindestens `domain` muss gesetzt sein.

Beispiel:

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

Anlegen:

```bash
kubectl apply -f global-config.yaml
```

## 2. Initiales Admin-Passwort-Secret

Das initiale Passwort des LDAP-Admin-Users unter `ou=People` wird aus einem Secret gelesen.
Dieses Passwort wird nur bei der ersten Initialisierung der LDAP-Daten verwendet.

Standardmäßig erzeugt Helm dieses Secret automatisch:

- Secret-Name: `<release>-initial-admin-password`
- Passwort-Key: `password`

Ein manuelles Secret ist nur nötig, wenn ein fester Initialwert vorgegeben werden soll oder `create=false` gesetzt wird.

Beispiel:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: lop-idp-ldap-initial-admin-password
  namespace: ecosystem
type: Opaque
stringData:
  password: "admin"
```

Anlegen:

```bash
kubectl apply -f ldap-initial-admin-password.yaml
```

## 3. Installation/Deinstallation per Make-Targets

`helm-apply` / `helm-delete` (Helm-Release):

```bash
make helm-apply
make helm-delete
```

`component-apply` / `component-delete` (Komponenten-CR):

```bash
make component-apply
make component-delete
```

## 4. Konfiguration (`values.yaml`) im Überblick

| Bereich                 | Schlüssel in `values.yaml`                              | Pflicht   | Wirkung                                                                 |
|-------------------------|---------------------------------------------------------|-----------|-------------------------------------------------------------------------|
| Allgemein               | `replicas`                                              | Nein      | Anzahl der Pod-Replikate im StatefulSet.                                |
| Image & Pull            | `global.imagePullSecrets`                               | Ja        | Pull-Secret(s) für das Container-Image.                                 |
| Image & Pull            | `image.registry`                                        | Ja        | Container-Registry des LDAP-Images.                                     |
| Image & Pull            | `image.repository`                                      | Ja        | Repository des LDAP-Images.                                             |
| Image & Pull            | `image.tag`                                             | Ja        | Image-Tag des LDAP-Containers.                                          |
| Image & Pull            | `imagePullPolicy`                                       | Ja        | Pull-Verhalten des Kubernetes-Containers.                               |
| Service                 | `service.port`                                          | Ja        | LDAP-Service-Port (Container/Service).                                  |
| LDAP-Config             | `config.password_change.notification_enabled`           | Nein      | Aktiviert/deaktiviert Passwortänderungs-Benachrichtigungen.             |
| LDAP-Config             | `config.password_change.check_interval_minutes`         | Nein      | Intervall für den Passwortänderungs-Check.                              |
| LDAP-Config             | `config.password_change.mail_sender_address`            | Nein      | Absenderadresse für Passwortänderungs-Mails.                            |
| LDAP-Config             | `config.password_change.mail_sender_name`               | Nein      | Anzeigename des Mail-Absenders.                                         |
| LDAP-Config             | `config.password_change.mail_subject`                   | Nein      | Betreff der Passwortänderungs-Mail.                                     |
| LDAP-Config             | `config.password_change.mail_text`                      | Nein      | Inhalt/Template der Passwortänderungs-Mail.                             |
| LDAP-Config             | `config.logging.root`                                   | Nein      | Log-Level für LDAP-Skripte und Startup-Logik.                           |
| LDAP-Config             | `config.user_search_size_limit`                         | Nein      | Maximale Ergebnisgröße für User-Suchen.                                 |
| LDAP-Config             | `config.max_db_size`                                    | Nein      | Maximale LDAP-DB-Größe (`olcDbMaxSize`).                                |
| LDAP-Config             | `config.admin_username`                                 | Nein      | Username des initialen Admin-Users.                                     |
| LDAP-Config             | `config.admin_member`                                   | Nein      | Steuert Mitgliedschaft des Admins in der Admin-Gruppe.                  |
| LDAP-Config             | `config.admin_givenname`                                | Nein      | Vorname des initialen Admin-Users.                                      |
| LDAP-Config             | `config.admin_surname`                                  | Nein      | Nachname des initialen Admin-Users.                                     |
| LDAP-Config             | `config.admin_displayname`                              | Nein      | Anzeigename des initialen Admin-Users.                                  |
| LDAP-Config             | `config.admin_mail`                                     | Nein      | E-Mail des initialen Admin-Users.                                       |
| LDAP-Config             | `config.openldap_suffix`                                | Nein      | LDAP-Suffix, z. B. `dc=cloudogu,dc=com`.                                |
| Globale CES-Config      | `globalConfig.configMapName`                            | Ja        | Name der globalen CES-ConfigMap.                                        |
| Globale CES-Config      | `globalConfig.key`                                      | Ja        | Key in der globalen ConfigMap (typisch `config.yaml`).                  |
| Initiales Admin-Secret  | `secrets.initialAdminPasswordSecretRef.create`          | Nein      | Erzeugt das Secret für das initiale Admin-Passwort per Helm.            |
| Initiales Admin-Secret  | `secrets.initialAdminPasswordSecretRef.name`            | Nein      | Name des Secrets mit dem initialen Admin-Passwort. Leer = Default-Name. |
| Initiales Admin-Secret  | `secrets.initialAdminPasswordSecretRef.passwordKey`     | Nein      | Key im Secret mit dem Passwortwert.                                     |
| Service-Account Secrets | `secrets.serviceAccounts.cas.enabled`                   | Nein      | Aktiviert/deaktiviert den CAS-Service-Account (RW).                     |
| Service-Account Secrets | `secrets.serviceAccounts.cas.secret.create`             | Nein      | Erzeugt CAS-Secret per Helm.                                            |
| Service-Account Secrets | `secrets.serviceAccounts.cas.secret.name`               | Nein      | Secret-Name für CAS-Credentials.                                        |
| Service-Account Secrets | `secrets.serviceAccounts.cas.secret.usernameKey`        | Nein      | Username-Key im CAS-Secret.                                             |
| Service-Account Secrets | `secrets.serviceAccounts.cas.secret.passwordKey`        | Nein      | Passwort-Key im CAS-Secret.                                             |
| Service-Account Secrets | `secrets.serviceAccounts.usermgt.enabled`               | Nein      | Aktiviert/deaktiviert den UserMgmt-Service-Account (RW).                |
| Service-Account Secrets | `secrets.serviceAccounts.usermgt.secret.create`         | Nein      | Erzeugt UserMgmt-Secret per Helm.                                       |
| Service-Account Secrets | `secrets.serviceAccounts.usermgt.secret.name`           | Nein      | Secret-Name für UserMgmt-Credentials.                                   |
| Service-Account Secrets | `secrets.serviceAccounts.usermgt.secret.usernameKey`    | Nein      | Username-Key im UserMgmt-Secret.                                        |
| Service-Account Secrets | `secrets.serviceAccounts.usermgt.secret.passwordKey`    | Nein      | Passwort-Key im UserMgmt-Secret.                                        |
| Service-Account Secrets | `secrets.serviceAccounts.ldapMapper.enabled`            | Nein      | Aktiviert/deaktiviert den LDAP-Mapper-Service-Account (RO).             |
| Service-Account Secrets | `secrets.serviceAccounts.ldapMapper.secret.create`      | Nein      | Erzeugt LDAP-Mapper-Secret per Helm.                                    |
| Service-Account Secrets | `secrets.serviceAccounts.ldapMapper.secret.name`        | Nein      | Secret-Name für LDAP-Mapper-Credentials.                                |
| Service-Account Secrets | `secrets.serviceAccounts.ldapMapper.secret.usernameKey` | Nein      | Username-Key im LDAP-Mapper-Secret.                                     |
| Service-Account Secrets | `secrets.serviceAccounts.ldapMapper.secret.passwordKey` | Nein      | Passwort-Key im LDAP-Mapper-Secret.                                     |
| Persistenz              | `persistence.size`                                      | Ja        | PVC-Größe für LDAP-Daten und Konfigurationsdaten.                       |
| Persistenz              | `persistence.storageClassName`                          | Nein      | StorageClass für das StatefulSet-PVC.                                   |
| Sicherheit              | `podSecurityContext.fsGroup`                            | Ja        | Dateisystem-Gruppe auf Pod-Ebene.                                       |
| Sicherheit              | `securityContext.runAsUser`                             | Ja        | Laufzeit-UID des LDAP-Containers.                                       |
| Sicherheit              | `securityContext.runAsGroup`                            | Ja        | Laufzeit-GID des LDAP-Containers.                                       |
| Sicherheit              | `securityContext.runAsNonRoot`                          | Ja        | Erzwingt Non-root-Containerlaufzeit.                                    |
| Sicherheit              | `securityContext.allowPrivilegeEscalation`              | Ja        | Erlaubt/verbietet Privileg-Eskalation im Container.                     |
| Sicherheit              | `securityContext.capabilities.drop`                     | Ja        | Linux-Capabilities, die im Container gedroppt werden.                   |
| Ressourcen              | `resources.requests.cpu`                                | Empfohlen | CPU-Request des LDAP-Containers.                                        |
| Ressourcen              | `resources.requests.memory`                             | Empfohlen | Memory-Request des LDAP-Containers.                                     |
| Ressourcen              | `resources.limits.memory`                               | Empfohlen | Memory-Limit des LDAP-Containers.                                       |

### Service-Account-Verhalten

- Bei `secret.create=true` erzeugt Helm ein Secret.
- Falls ein Secret bereits existiert, werden vorhandene Werte weiterverwendet.
- Fehlt `username`, wird ein Default-Username verwendet (`cas`, `usermgt`, `ldap-mapper`).
- Fehlt `password`, wird ein zufälliges Passwort generiert.
- Beim Startup werden die LDAP-Service-Accounts mit den Secret-Daten abgeglichen (create/update/delete).
- Wenn ein Account deaktiviert ist oder Secret-Daten fehlen, wird der zugehörige LDAP-Service-Account entfernt.

Hinweis für ArgoCD/GitOps:

- Bei strikt deklarativem Betrieb ohne Helm-`lookup` empfiehlt sich `secret.create=false` und extern verwaltete Secrets.

### Verhalten des initialen Admin-Passworts

- Bei `secrets.initialAdminPasswordSecretRef.create=true` erzeugt Helm ein Secret mit einem zufälligen Passwort, falls noch keines existiert.
- Falls das Secret bereits existiert, wird das vorhandene Passwort weiterverwendet.
- Das Secret liefert nur das initiale Passwort für den LDAP-Admin-User in `ou=People`.
- Nach der ersten Initialisierung ist LDAP selbst führend. Änderungen des Passworts über UserMgt oder LDAP werden nicht in das Secret zurückgeschrieben.

### Beispiel-Overrides

```yaml
globalConfig:
  configMapName: global-config
  key: config.yaml

secrets:
  initialAdminPasswordSecretRef:
    create: true
    name: ""
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

## 5. Deinstallation

```bash
make helm-delete
make component-delete
```

Das PVC bleibt je nach StorageClass-ReclaimPolicy erhalten oder wird automatisch entfernt.
