# Set these to the desired values
ARTIFACT_ID=ldap
VERSION=2.4.58-2
MAKEFILES_VERSION=4.8.0
.DEFAULT_GOAL:=default

include build/make/variables.mk
include build/make/self-update.mk
include build/make/release.mk
include bats.mk

default: dogu-release
