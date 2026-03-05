# Set these to the desired values
DOGU_IMAGE?=registry.cloudogu.com/official/ldap:$(VERSION)
.DEFAULT_GOAL:=default

include build/make/variables.mk
include build/make/release.mk
include build/make/k8s-dogu.mk
include build/make/prerelease.mk
include bats.mk
