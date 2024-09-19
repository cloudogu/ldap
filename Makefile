# Set these to the desired values
ARTIFACT_ID=ldap
VERSION=2.6.7-4
MAKEFILES_VERSION=9.1.0
.DEFAULT_GOAL:=default

include build/make/variables.mk
include build/make/self-update.mk
include build/make/release.mk
include build/make/k8s-dogu.mk
include bats.mk

default: dogu-release