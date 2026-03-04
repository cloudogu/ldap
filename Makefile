# Set these to the desired values
ARTIFACT_ID=ldap
VERSION=2.6.8-7
MAKEFILES_VERSION=10.5.0
DOGU_IMAGE?=registry.cloudogu.com/official/ldap:$(VERSION)
COMPONENT_IMAGE?=registry.cloudogu.com/k8s/ldap:$(VERSION)
.DEFAULT_GOAL:=default

include build/make/variables.mk
include build/make/self-update.mk
include build/make/release.mk
include build/make/k8s-dogu.mk
include build/make/prerelease.mk
include bats.mk

default: dogu-release

.PHONY: docker-build-dogu
docker-build-dogu:
	docker build --target dogu -t $(DOGU_IMAGE) .

.PHONY: docker-build-component
docker-build-component:
	docker build --target component -t $(COMPONENT_IMAGE) .

.PHONY: component-apply
component-apply:
	$(MAKE) -f Makefile.component component-apply

.PHONY: helm-apply
helm-apply:
	$(MAKE) -f Makefile.component helm-apply

.PHONY: helm-delete
helm-delete:
	$(MAKE) -f Makefile.component helm-delete