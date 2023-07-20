#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

function installCespersonIfNecessary() {
  if ! ldapsearch -b "cn=schema,cn=config" '(&(objectClass=olcSchemaConfig)(cn=*cesperson))' 2>&1 | grep "numEntries: 1" &> /dev/null; then
    echo "Cesperson does not exist. Adding..."
    ldapadd -f /srv/openldap/schema/cesperson.ldif
  fi
}
