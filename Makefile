# Central configuration for both build paths.
VERSION=2.6.8-7
MAKEFILES_VERSION=10.5.0

include build/make/variables.mk
include build/make/self-update.mk

# Child makefiles.
DOGU_MAKEFILE?=make/dogu.mk
COMPONENT_MAKEFILE?=make/component.mk

# Shared vars passed to child makefiles.
DOGU_MAKE_VARS=VERSION=$(VERSION)
COMPONENT_MAKE_VARS=VERSION=$(VERSION)

# Small helper wrappers to keep forwarded targets readable.
run_dogu = $(MAKE) -f $(DOGU_MAKEFILE) $(DOGU_MAKE_VARS) $(1)
run_component = $(MAKE) -f $(COMPONENT_MAKEFILE) $(COMPONENT_MAKE_VARS) $(1)

.DEFAULT_GOAL:=default

.PHONY: default
default: dogu-release

##@ CI / Release

.PHONY: ci-dogu
ci-dogu: dogu-build dogu-test ## Run dogu CI build and test targets.

.PHONY: ci-component
ci-component: component-build component-test ## Run component CI build and test targets.

.PHONY: ci
ci: ci-dogu ci-component ## Run CI targets for dogu and component.

.PHONY: component-release
component-release: component-helm-package ## Package Helm chart for component release.

.PHONY: release
release: dogu-release component-release ## Run release targets for both artifacts.

##@ Dogu

.PHONY: dogu-build
dogu-build:
	$(call run_dogu,build)

.PHONY: dogu-unit-test-shell-ci
dogu-unit-test-shell-ci:
	$(call run_dogu,unit-test-shell-ci)

.PHONY: dogu-unit-test-shell-local
dogu-unit-test-shell-local:
	$(call run_dogu,unit-test-shell-local)

##@ Component

.PHONY: component-build
component-build: ## Build the component image.
	$(call run_component,component-build)

.PHONY: component-test
component-test: ## Run component chart lint checks.
	$(call run_component,helm-lint)

.PHONY: component-apply
component-apply:
	$(call run_component,component-apply)

.PHONY: component-delete
component-delete:
	$(call run_component,component-delete)

.PHONY: component-reinstall
component-reinstall:
	$(call run_component,component-reinstall)

.PHONY: component-helm-generate
component-helm-generate:
	$(call run_component,helm-generate)

.PHONY: component-helm-lint
component-helm-lint:
	$(call run_component,helm-lint)

.PHONY: component-helm-package
component-helm-package:
	$(call run_component,helm-package)

.PHONY: component-helm-apply
component-helm-apply:
	$(call run_component,helm-apply)

.PHONY: component-helm-delete
component-helm-delete:
	$(call run_component,helm-delete)

##@ Compatibility

.PHONY: unit-test-shell-ci
unit-test-shell-ci:
	$(call run_dogu,unit-test-shell-ci)

.PHONY: unit-test-shell-generic
unit-test-shell-generic:
	$(call run_dogu,unit-test-shell-generic)

.PHONY: buildTestImage
buildTestImage:
	$(call run_dogu,buildTestImage)

.PHONY: prerelease_namespace
prerelease_namespace:
	$(call run_dogu,prerelease_namespace)
