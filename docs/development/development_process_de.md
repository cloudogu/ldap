# Entwicklungsprozess (Dogu + Komponente)

## Ziel
Dieses Repository liefert zwei Artefakte mit gemeinsamer Version:

- LDAP-Dogu
- LDAP-Komponente (Helm/StatefulSet)

Build, Test und Release laufen zentral über ein gemeinsames `Makefile` und ein gemeinsames `Jenkinsfile`.

## Lokaler Entwicklungsablauf

### 1. Dogu entwickeln und testen
- Build/Deploy (bestehender Dogu-Pfad):
  - `make build`
- Shell-Unit-Tests lokal:
  - `make unit-test-shell-local`
- Shell-Unit-Tests CI-ähnlich:
  - `make unit-test-shell-ci`

### 2. Komponente entwickeln und testen
- Gemeinsames Image bauen:
  - `make docker-build`
- Helm lint:
  - `make helm-lint`
- Helm-Chart generieren:
  - `make helm-generate`
- Komponente deployen/entfernen:
  - `make helm-apply`
  - `make helm-delete`
  - `make component-apply`
  - `make component-delete`

## CI-/Pipeline-Ablauf
Die Pipeline bleibt zentral in `Jenkinsfile`:

- Default-Dogu-Stages über `pipe.addDefaultStages()`
- zusätzliche Component-Stage-Group:
  - `Component Checkout`
  - `Component Build`
  - `Component Test`
  - `Component Smoke Test (k3d)`

Der Smoke-Test taggt das zuvor gebaute Image bewusst auf `local-smoke/ldap:<version>`, importiert es in den k3d-Cluster und deployt damit das Helm-Chart.

Auf Release-Branches werden zusätzlich ausgeführt:
- `Push Component Chart to Harbor`

## Release-Prozess (kombiniert)

### Zielbild
Ein Gitflow-Release aktualisiert Dogu- und Komponenten-Versionen gemeinsam.

### Einstieg
- Kombiniertes Release starten:
  - `make dogu-release`

Technisch:
- `make dogu-release` startet den Release-Lauf.
- Der Release-Lauf lädt `release_args.sh`.
- Dort werden zusätzlich zu den Standarddateien auch Component-Dateien versioniert:
  - `k8s/helm/values.yaml` (`image.tag`)
  - `k8s/helm/component-patch-tpl.yaml` (`values.images.ldap`)
