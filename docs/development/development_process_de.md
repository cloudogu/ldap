# Entwicklungsprozess (Dogu + Komponente)

## Ziel
Dieses Repository liefert zwei Artefakte mit gemeinsamer Version:

- LDAP-Dogu
- LDAP-Komponente (Helm/StatefulSet)

Build, Test und Release laufen zentral über ein gemeinsames `Makefile` und ein gemeinsames `Jenkinsfile`.

## Aufbau
- Zentrales Entry-Point-Makefile: `Makefile`
- Dogu-spezifische Targets: `make/dogu.mk`
- Komponenten-spezifische Targets: `make/component.mk`
- Kombinierte Release-Hooks: `release_args.sh`
- CI/CD-Pipeline: `Jenkinsfile`

Wichtige Leitlinie:
- `VERSION` wird zentral im Root-`Makefile` gepflegt und für Dogu + Komponente gemeinsam verwendet.

## Lokaler Entwicklungsablauf

### 1. Dogu entwickeln und testen
- Build/Deploy (bestehender Dogu-Pfad):
  - `make dogu-build`
- Shell-Unit-Tests lokal:
  - `make dogu-unit-test-shell-local`
- Shell-Unit-Tests CI-ähnlich:
  - `make dogu-unit-test-shell-ci`

### 2. Komponente entwickeln und testen
- Image bauen:
  - `make component-build`
- Helm lint:
  - `make component-test`
- Helm-Chart generieren:
  - `make component-helm-generate`
- Komponente deployen/entfernen:
  - `make component-apply`
  - `make component-delete`

## CI-/Pipeline-Ablauf
Die Pipeline bleibt zentral in `Jenkinsfile`:

- Default-Dogu-Stages über `pipe.addDefaultStages()`
- zusätzliche Component-Stage-Group:
  - `Component Build`
  - `Component Test`
  - `Component Smoke Test (k3d)`

Der Smoke-Test importiert bewusst ein lokal gebautes Image (`local-smoke/ldap:<version>`) in den k3d-Cluster und deployt damit das Helm-Chart.

Auf Release-Branches werden zusätzlich ausgeführt:
- `Push Component Image`
- `Push Component Chart to Harbor`

## Release-Prozess (kombiniert)

### Zielbild
Ein Gitflow-Release aktualisiert Dogu- und Komponenten-Versionen gemeinsam.

### Einstieg
- Kombiniertes Release starten:
  - `make release`

Technisch:
- `make release` ruft `dogu-release` auf.
- Der Release-Lauf lädt `release_args.sh`.
- Dort werden zusätzlich zu den Standarddateien auch Component-Dateien versioniert:
  - `k8s/helm/values.yaml` (`image.tag`)
  - `k8s/helm/component-patch-tpl.yaml` (`values.images.ldap`)

## Pflege von Build-Libs
- Makefiles-Library aktualisieren:
  - `make update-makefiles`

Hinweis:
- Änderungen an Build-Libs nur allgemein und wiederverwendbar einbringen (`makefiles`, `pipe-build-lib`, `ces-build-lib`, `dogu-build-lib`).

## Kurzreferenz Befehle
- `make dogu-build`
- `make dogu-unit-test-shell-local`
- `make dogu-unit-test-shell-ci`
- `make component-build`
- `make component-test`
- `make component-apply`
- `make component-delete`
- `make ci`
- `make release`
