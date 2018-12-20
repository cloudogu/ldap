#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail


CONFIG_DIR=/etc/openldap
MIGRATION_FOLDER=/var/lib/openldap/migration

FROM_VERSION="${1}"
TO_VERSION="${2}"

echo "Post-upgrade: Upgrading from ${FROM_VERSION} to ${TO_VERSION}"
echo "maybe move migration data to correct folder here instead of in the startup.sh"
