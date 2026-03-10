# Development Process (Dogu + Component)

## Goal
This repository delivers two artifacts with a shared version:

- LDAP Dogu
- LDAP component (Helm/StatefulSet)

Build, test, and release are managed centrally through one shared `Makefile` and one shared `Jenkinsfile`.

## Structure
- Central entry-point makefile: `Makefile`
- Dogu-specific targets: `make/dogu.mk`
- Component-specific targets: `make/component.mk`
- Combined release hooks: `release_args.sh`
- CI/CD pipeline: `Jenkinsfile`

Key guideline:
- `VERSION` is maintained centrally in the root `Makefile` and is shared by dogu and component.

## Local Development Workflow

### 1. Develop and test dogu
- Build/deploy (existing dogu path):
  - `make dogu-build`
- Shell unit tests (local):
  - `make dogu-unit-test-shell-local`
- Shell unit tests (CI-like):
  - `make dogu-unit-test-shell-ci`

### 2. Develop and test component
- Build image:
  - `make component-build`
- Helm lint:
  - `make component-test`
- Generate Helm chart:
  - `make component-helm-generate`
- Deploy/remove component:
  - `make component-apply`
  - `make component-delete`

## CI/Pipeline Workflow
The pipeline remains centralized in `Jenkinsfile`:

- Default dogu stages via `pipe.addDefaultStages()`
- Additional component stage group:
  - `Component Build`
  - `Component Test`
  - `Component Smoke Test (k3d)`

The smoke test intentionally imports a locally built image (`local-smoke/ldap:<version>`) into the k3d cluster and deploys the Helm chart with it.

On release branches, the following stages run additionally:
- `Push Component Image`
- `Push Component Chart to Harbor`

## Release Process (Combined)

### Target
One gitflow release updates dogu and component versions together.

### Entry
- Start combined release:
  - `make release`

Technical flow:
- `make release` calls `dogu-release`.
- The release run loads `release_args.sh`.
- In addition to standard files, component files are versioned as well:
  - `k8s/helm/values.yaml` (`image.tag`)
  - `k8s/helm/component-patch-tpl.yaml` (`values.images.ldap`)

## Build Lib Maintenance
- Update makefiles library:
  - `make update-makefiles`

Note:
- Keep changes to build libs generic and reusable (`makefiles`, `pipe-build-lib`, `ces-build-lib`, `dogu-build-lib`).

## Command Reference
- `make dogu-build`
- `make dogu-unit-test-shell-local`
- `make dogu-unit-test-shell-ci`
- `make component-build`
- `make component-test`
- `make component-apply`
- `make component-delete`
- `make ci`
- `make release`
