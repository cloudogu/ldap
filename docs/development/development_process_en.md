# Development Process (Dogu + Component)

## Goal
This repository delivers two artifacts with a shared version:

- LDAP Dogu
- LDAP component (Helm/StatefulSet)

Build, test, and release are managed centrally through one shared `Makefile` and one shared `Jenkinsfile`.

## Local Development Workflow

### 1. Develop and test dogu
- Build/deploy (existing dogu path):
  - `make build`
- Shell unit tests (local):
  - `make unit-test-shell-local`
- Shell unit tests (CI-like):
  - `make unit-test-shell-ci`

### 2. Develop and test component
- Build shared image:
  - `make docker-build`
- Helm lint:
  - `make helm-lint`
- Generate Helm chart:
  - `make helm-generate`
- Deploy/remove component:
  - `make helm-apply`
  - `make helm-delete`
  - `make component-apply`
  - `make component-delete`

## CI/Pipeline Workflow
The pipeline remains centralized in `Jenkinsfile`:

- Default dogu stages via `pipe.addDefaultStages()`
- Additional component stage group:
  - `Component Checkout`
  - `Component Build`
  - `Component Test`
  - `Component Smoke Test (k3d)`

The smoke test intentionally retags the previously built image to `local-smoke/ldap:<version>`, imports it into the k3d cluster, and deploys the Helm chart with it.

On release branches, the following stages run additionally:
- `Push Component Chart to Harbor`

## Release Process (Combined)

### Target
One gitflow release updates dogu and component versions together.

### Entry
- Start combined release:
  - `make dogu-release`

Technical flow:
- `make dogu-release` starts the release run.
- The release run loads `release_args.sh`.
- In addition to standard files, component files are versioned as well:
  - `k8s/helm/values.yaml` (`image.tag`)
  - `k8s/helm/component-patch-tpl.yaml` (`values.images.ldap`)
