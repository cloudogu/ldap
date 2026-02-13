# Set these to the desired values
ARTIFACT_ID=ldap
VERSION=2.6.8-6
MAKEFILES_VERSION=10.5.0
.DEFAULT_GOAL:=default

include build/make/variables.mk
include build/make/self-update.mk
include build/make/release.mk
include build/make/k8s-dogu.mk
include build/make/prerelease.mk
include bats.mk

default: dogu-release
