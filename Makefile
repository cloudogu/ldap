# Set these to the desired values
ARTIFACT_ID=ldap
VERSION=2.4.48-4
MAKEFILES_VERSION=4.8.0
.DEFAULT_GOAL:=default

include build/make/variables.mk
include build/make/self-update.mk
include build/make/release.mk

default: dogu-release
