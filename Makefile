# Set these to the desired values
ARTIFACT_ID=ldap
VERSION=2.6.7-2
MAKEFILES_VERSION=7.10.0
.DEFAULT_GOAL:=default

include build/make/variables.mk
include build/make/self-update.mk
include build/make/release.mk
include bats.mk

default: dogu-release