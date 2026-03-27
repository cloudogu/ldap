# LDAP-Migration vom Dogu zur Komponente

Dieses Dokument beschreibt, wie die Migration einer bestehenden LDAP-Dogu-Instanz zur LDAP-Komponente funktioniert und wie sie im Betrieb anzuwenden ist.

## Ziel und Ergebnis

Die Migration übernimmt die bestehenden LDAP-Daten des Dogus in die LDAP-Komponente, damit ein bestehendes System ohne Neuaufbau der Benutzer- und Gruppendaten weiterbetrieben werden kann.

Nach einer erfolgreichen Migration gilt:

- die LDAP-Komponente läuft mit den migrierten Daten,
- das alte LDAP-Dogu ist gestoppt,
- das alte LDAP-Dogu ist auf `pauseReconciliation=true` gesetzt,
- eine erneute automatische Migration wird nicht mehr ausgeführt.

Die spätere Deinstallation des alten LDAP-Dogus ist nicht Teil des automatischen Migrationsablaufs. 
Sie erfolgt anschließend bewusst über den Blueprint, indem das Dogu auf `absent: true` gesetzt wird.

## Voraussetzungen

Vor der Migration müssen folgende Bedingungen erfüllt sein:

- das LDAP-Dogu ist im Cluster vorhanden,
- das LDAP-Dogu-PVC existiert unter dem festen Namen `ldap`,
- die LDAP-Komponente wird mit aktiviertem Migrationspfad installiert oder aktualisiert,
- `migration.enabled=true` ist im Chart gesetzt,
- globale LDAP-relevante Konfiguration der Komponente ist passend gesetzt, insbesondere:
  - `globalConfig.configMapName`
  - `globalConfig.key`
  - `config.openldap_suffix`
- ein Ziel-PVC für die LDAP-Komponente kann durch das StatefulSet erzeugt werden.

## Was genau migriert wird

Es wird nur die LDAP-Datenbank aus dem Dogu übernommen.

Konkret:

- Quellpfad: `db` im PVC des LDAP-Dogus
- Zielpfad: `db` im PVC der LDAP-Komponente
- kopiert werden die MDB-Daten der LDAP-Datenbank
- nicht übernommen wird die alte `cn=config`-Konfiguration des Dogus

Wichtig:

- die LDAP-Komponente erzeugt ihre eigene Konfiguration selbst,
- die Migration kopiert danach nur die eigentlichen LDAP-Daten,
- der Laufzeitpfad `run` wird nicht übernommen.
- vor dem eigentlichen Cutover wird geprüft, ob Dogu und Komponente dieselbe wesentliche LDAP-Konfiguration verwenden.

## Wie die Migration technisch abläuft

Die Migration ist als Helm-Hook im LDAP-Chart implementiert und läuft automatisch bei `post-install` und `post-upgrade`.

Wichtig:

- beim ersten Installieren der Komponente kann das StatefulSet kurz initial starten,
- der erste Hook-Job skaliert das Ziel-StatefulSet anschließend gezielt auf `0`,
- danach werden die Daten übernommen und das Ziel erneut gestartet.

Es gibt zwei Hook-Jobs:

1. `*-migration-stop-source`
   - validiert vor dem Cutover die wesentliche Konfiguration von Dogu und Komponente,
   - setzt das LDAP-Dogu auf `spec.stopped=true`,
   - wartet, bis die LDAP-Dogu-Pods beendet sind,
   - setzt anschließend `spec.pauseReconciliation=true`,
   - skaliert das Ziel-StatefulSet der LDAP-Komponente auf `0`.

2. `*-migration-copy-and-start`
   - mountet Quell- und Ziel-PVC,
   - kopiert die LDAP-Datenbank vom Dogu in das Komponenten-PVC,
   - setzt den Migrationsstatus auf `done`,
   - startet das StatefulSet der LDAP-Komponente wieder.

Wenn der zweite Job fehlschlägt:

- wird der Migrationsstatus auf `failed` gesetzt,
- das LDAP-Dogu wird wieder gestartet,
- `pauseReconciliation` wird wieder auf `false` gesetzt.

Die Konfigurationsvalidierung prüft aktuell als harte Vorbedingung:

- `domain`
- `openldap_suffix`

Bei einer Abweichung wird die Migration vor dem Stoppen des LDAP-Dogus abgebrochen.

## Migrationsstatus

Der aktuelle Status wird in der ConfigMap `<release>-config` unter dem Key `migrationPhase` gespeichert.

Mögliche Werte:

| Wert                | Bedeutung                                                                           |
|---------------------|-------------------------------------------------------------------------------------|
| `pending`           | Migration wurde noch nicht abgeschlossen.                                           |
| `running`           | Migration läuft aktuell.                                                            |
| `done`              | Migration wurde erfolgreich abgeschlossen.                                          |
| `failed`            | Migration ist fehlgeschlagen.                                                       |
| `skipped_no_source` | Es wurden keine Quelldaten gefunden, daher wurde keine Datenübernahme durchgeführt. |

Wichtig:

- bei `done` und `skipped_no_source` werden die Migrationsjobs bei weiteren Upgrades nicht erneut ausgeführt,
- bei `failed` kann die Migration nach Fehlerbehebung durch ein erneutes Upgrade erneut angestoßen werden.

## Anwendung im Betrieb

### Variante 1: Installation über Helm

Die Migration läuft automatisch, wenn die LDAP-Komponente mit aktivierter Migration installiert oder aktualisiert wird.

Beispiel:

```bash
helm upgrade --install ldap k8s/helm \
  --namespace ecosystem \
  --set migration.enabled=true
```

Alternativ über das Make-Target:

```bash
make helm-apply
```

### Variante 2: Installation über die Komponenten-CR

Wenn die LDAP-Komponente über den Component-Operator ausgebracht wird, läuft die Migration ebenfalls automatisch mit dem Helm-Release im Hintergrund.

Beispiel:

```bash
make component-apply
```

### Variante 3: Nutzung über das LOP-IdP Umbrella-Chart

Wenn LDAP Teil des LOP-IdP Umbrella-Charts ist, wird die Migration beim Installieren oder Aktualisieren dieses Umbrella-Charts automatisch mit ausgeführt, solange für LDAP `migration.enabled=true` gesetzt ist.

## Nachkontrolle

Nach einer erfolgreichen Migration sollten mindestens diese Prüfungen durchgeführt werden:

```bash
kubectl -n ecosystem get dogu ldap -o jsonpath='{.spec.stopped}{"\n"}{.spec.pauseReconciliation}{"\n"}'
kubectl -n ecosystem get configmap ldap-config -o jsonpath='{.data.migrationPhase}{"\n"}'
kubectl -n ecosystem rollout status statefulset/ldap --timeout=300s
kubectl -n ecosystem get pod -l app.kubernetes.io/instance=ldap
```

Erwartetes Ergebnis:

- `spec.stopped=true`,
- `spec.pauseReconciliation=true`,
- `migrationPhase=done`,
- das StatefulSet `ldap` ist `Ready`.

Hinweis:

- erfolgreiche Hook-Jobs werden automatisch wieder gelöscht,
- im Erfolgsfall erfolgt die Nachkontrolle daher über den Zustand von Dogu, ConfigMap und StatefulSet,
- bei Fehlern bleiben die fehlgeschlagenen Jobs erhalten und können per `kubectl logs job/...` untersucht werden.

Zusätzlich sollte fachlich geprüft werden:

- Benutzer sind weiterhin vorhanden,
- Gruppen sind weiterhin vorhanden,
- Anmeldung mit bekannten LDAP-Benutzern funktioniert,
- Service-Accounts der Komponente sind vorhanden und funktionsfähig.


## Fehlerfall und Rollback

Wenn die Migration fehlschlägt, ist der relevante automatische Rollback-Pfad:

- `migrationPhase=failed`,
- das LDAP-Dogu wird wieder gestartet,
- `pauseReconciliation` wird wieder auf `false` gesetzt.

Prüfung im Fehlerfall:

```bash
kubectl -n ecosystem get dogu ldap -o jsonpath='{.spec.stopped}{"\n"}{.spec.pauseReconciliation}{"\n"}'
kubectl -n ecosystem get configmap ldap-config -o jsonpath='{.data.migrationPhase}{"\n"}'
kubectl -n ecosystem logs job/ldap-migration-stop-source
kubectl -n ecosystem logs job/ldap-migration-copy-and-start
```

Erwartetes Ergebnis nach einem Fehler in Schritt 2:

- `spec.stopped=false`,
- `spec.pauseReconciliation=false`,
- `migrationPhase=failed`,
- das LDAP-Dogu ist wieder verfügbar.

Nach Fehlerbehebung kann die Migration durch ein erneutes Install/Upgrade erneut angestoßen werden.

## Abschluss nach erfolgreicher Migration

Nach erfolgreicher Migration verbleibt das alte LDAP-Dogu zunächst bewusst im Cluster, aber inaktiv:

- `stopped=true`
- `pauseReconciliation=true`

Erst wenn der neue Zustand ausreichend verifiziert ist, sollte das alte LDAP-Dogu im Blueprint auf `absent: true` gesetzt und damit deinstalliert werden.

Dieser Cleanup-Schritt ist bewusst getrennt vom automatischen Migrationsablauf.
