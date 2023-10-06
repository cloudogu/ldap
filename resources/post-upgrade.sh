#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

source /pre-upgrade.sh

function start_migration() {
  echo "[DOGU] Moving exports ..."
  mkdir -p "${MIGRATION_TMP_DIR}"
  cp /var/lib/openldap/migration/config.ldif "${MIGRATION_TMP_DIR}"
  cp /var/lib/openldap/migration/data.ldif "${MIGRATION_TMP_DIR}"

  echo "[DOGU] Changing config ..."
  sed -i 's/olcSizeLimit: 1000/olcSizeLimit: 3000/g' "${MIGRATION_TMP_DIR}"/config.ldif
  sed -i '/back_bdb.so/d' "${MIGRATION_TMP_DIR}"/config.ldif
  sed -i '/back_hdb.so/d' "${MIGRATION_TMP_DIR}"/config.ldif
  sed -i 's/hdb/mdb/g' "${MIGRATION_TMP_DIR}"/config.ldif
  sed -i 's/Hdb/Mdb/g' "${MIGRATION_TMP_DIR}"/config.ldif
  sed -i '/olcDbCheckpoint/d' "${MIGRATION_TMP_DIR}"/config.ldif
  sed -i '/set_cachesize/d' "${MIGRATION_TMP_DIR}"/config.ldif
  sed -i '/set_lk_max_locks/d' "${MIGRATION_TMP_DIR}"/config.ldif
  sed -i '/set_lk_max_objects/d' "${MIGRATION_TMP_DIR}"/config.ldif
  sed -i '/set_lk_max_lockers/d' "${MIGRATION_TMP_DIR}"/config.ldif
  sed -i '/dn: cn={4}ppolicy/,/^$/d' "${MIGRATION_TMP_DIR}"/config.ldif

  clean_config_data
  import_dump

  echo "[DOGU] Setting rights correctly ..."
  chmod -R 700 /etc/openldap/slapd.d
  chmod -R 700 /var/lib/openldap
  chown -R ldap:ldap /etc/openldap/slapd.d
  chown -R ldap:ldap /var/lib/openldap

  doguctl config --rm migration_mdb_hdb
  rm -rf "${MIGRATION_TMP_DIR}"
}


function clean_config_data() {
    echo "[DOGU] Cleanup config and db folders ..."
    rm -rf /etc/openldap/slapd.d/*
    rm -rf /var/lib/openldap/*
}


function import_dump() {
  echo "[DOGU] Importing dump ..."
  slapadd -n 0 -F /etc/openldap/slapd.d -l "${MIGRATION_TMP_DIR}"/config.ldif
  slapadd -n 1 -F /etc/openldap/slapd.d -l "${MIGRATION_TMP_DIR}"/data.ldif
}

function run_postupgrade() {
  FROM_VERSION="${1}"
  TO_VERSION="${2}"
  echo "Running postupgrade..."

  if [[ -d "/var/lib/openldap/migration" ]]; then
    echo "Found data to migrate from old ldap..."
    start_migration
  fi
}

# make the script only run when executed, not when sourced from bats tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_postupgrade "$@"
fi
