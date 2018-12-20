#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

CONFIG_DIR=/etc/openldap
MIGRATION_FOLDER=/var/lib/openldap/migration

FROM_VERSION="${1}"
TO_VERSION="${2}"

echo "upgrading from ${FROM_VERSION} to ${TO_VERSION}"

if [[ $FROM_VERSION == 2.4.44-4 ]]; then
    echo "saving config data for migration"
    mkdir -p ${MIGRATION_FOLDER}
    echo "config dir:"
    ls -la ${CONFIG_DIR}
    echo "copying..."
    cp -r -p ${CONFIG_DIR}/* ${MIGRATION_FOLDER}
    echo "migration folder:"
    ls -lan ${MIGRATION_FOLDER}
fi
echo "sleeping for a minute..."
sleep 60
echo "done sleeping"