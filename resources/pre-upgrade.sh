#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

OPENLDAP_RUN_DIR="/var/run/openldap"
export OPENLDAP_RUN_PIDFILE="${OPENLDAP_RUN_DIR}/slapd.pid"
MIGRATION_TMP_DIR="/tmp/migration"

if [[ ! -d ${MIGRATION_TMP_DIR} ]]; then
  mkdir -p ${MIGRATION_TMP_DIR}
fi

function run_preupgrade() {
  FROM_VERSION="${1}"
  TO_VERSION="${2}"

  echo "Executing LDAP pre-upgrade from ${FROM_VERSION} to ${TO_VERSION}"

  if [ "${FROM_VERSION}" = "${TO_VERSION}" ]; then
    echo "FROM and TO versions are the same; Exiting..."
    exit 0
  fi

  echo "Set registry flag so startup script waits for post-upgrade to finish..."
  doguctl state "upgrading"

  if [[ "$(versionXLessOrEqualThanY "${FROM_VERSION}" "2.4.58-3"; echo $?)" == "0" ]]; then
    echo "Detected upgrade from <= 2.4.58-3: migrating from hdb to mbd"

    # exporting old config and data
    start_export
  fi

  doguctl config "startup/setup_done" "true"

  echo "LDAP pre-upgrade done"
}

# versionXLessOrEqualThanY returns true if X is less than or equal to Y; otherwise false
function versionXLessOrEqualThanY() {
  local sourceVersion="${1}"
  local targetVersion="${2}"

  if [[ "${sourceVersion}" == "${targetVersion}" ]]; then
    return 0
  fi

  declare -r semVerRegex='([0-9]+)\.([0-9]+)\.([0-9]+)-([0-9]+)'

  sourceMajor=0
  sourceMinor=0
  sourceBugfix=0
  sourceDogu=0
  targetMajor=0
  targetMinor=0
  targetBugfix=0
  targetDogu=0

  if [[ ${sourceVersion} =~ ${semVerRegex} ]]; then
    sourceMajor=${BASH_REMATCH[1]}
    sourceMinor="${BASH_REMATCH[2]}"
    sourceBugfix="${BASH_REMATCH[3]}"
    sourceDogu="${BASH_REMATCH[4]}"
  else
    echo "ERROR: source dogu version ${sourceVersion} does not seem to be a semantic version"
    exit 1
  fi

  if [[ ${targetVersion} =~ ${semVerRegex} ]]; then
    targetMajor=${BASH_REMATCH[1]}
    targetMinor="${BASH_REMATCH[2]}"
    targetBugfix="${BASH_REMATCH[3]}"
    targetDogu="${BASH_REMATCH[4]}"
  else
    echo "ERROR: target dogu version ${targetVersion} does not seem to be a semantic version"
    exit 1
  fi

  if [[ $((sourceMajor)) -lt $((targetMajor)) ]]; then
    return 0
  fi
  if [[ $((sourceMajor)) -le $((targetMajor)) && $((sourceMinor)) -lt $((targetMinor)) ]]; then
    return 0
  fi
  if [[ $((sourceMajor)) -le $((targetMajor)) && $((sourceMinor)) -le $((targetMinor)) && $((sourceBugfix)) -lt $((targetBugfix)) ]]; then
    return 0
  fi
  if [[ $((sourceMajor)) -le $((targetMajor)) && $((sourceMinor)) -le $((targetMinor)) && $((sourceBugfix)) -le $((targetBugfix)) && $((sourceDogu)) -lt $((targetDogu)) ]]; then
    return 0
  fi

  return 1
}

function start_export() {
  # Creating dump
  echo "[DOGU] exporting DB ..."
  slapcat -n 0 -l ${MIGRATION_TMP_DIR}/config.ldif
  slapcat -n 1 -l ${MIGRATION_TMP_DIR}/data.ldif
  mkdir -p /var/lib/openldap/migration
  cp ${MIGRATION_TMP_DIR}/config.ldif /var/lib/openldap/migration
  cp ${MIGRATION_TMP_DIR}/data.ldif /var/lib/openldap/migration
  doguctl config migration_mdb_hdb "true"
}

# versionXLessThanY returns true if X is less than Y; otherwise false
function versionXLessThanY() {
  if [[ "${1}" == "${2}" ]]; then
    return 1
  fi
  versionXLessOrEqualThanY "${1}" "${2}"
}

# make the script only run when executed, not when sourced from bats tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_preupgrade "$@"
fi
