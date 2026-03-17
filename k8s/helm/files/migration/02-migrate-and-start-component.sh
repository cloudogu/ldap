#!/bin/sh
set -eu

# shellcheck disable=SC2034
LOG_PREFIX="MIGRATION-STEP2"
COMMON_SH_PATH="${COMMON_SH_PATH:-/scripts/common.sh}"
# shellcheck source=/scripts/common.sh
# shellcheck disable=SC1091
. "${COMMON_SH_PATH}"

require_env "NAMESPACE"
require_env "COMPONENT_CONFIGMAP_NAME"
require_env "TARGET_STATEFULSET_NAME"
require_env "TARGET_REPLICAS"
require_env "SOURCE_VOLUME_PATH"
require_env "TARGET_VOLUME_PATH"

source_db_path="${SOURCE_VOLUME_PATH}/${SOURCE_DB_SUBPATH}"
target_db_path="${TARGET_VOLUME_PATH}/${TARGET_DB_SUBPATH}"

current_phase="$(get_migration_phase)"
if [ "${current_phase}" = "${MIGRATION_PHASE_DONE}" ] || [ "${current_phase}" = "${MIGRATION_PHASE_SKIPPED_NO_SOURCE}" ]; then
  log "Migration phase is '${current_phase}', ensure component is started."
  scale_target "${TARGET_REPLICAS}"
  exit 0
fi

cleanup_on_error() {
  rc="$?"
  if [ "${rc}" -ne 0 ]; then
    set +e
    log "Step 2 failed with exit code ${rc}."
    set_migration_phase "${MIGRATION_PHASE_FAILED}"
    log "Restart source LDAP dogu '${SOURCE_DOGU_NAME}'."
    k patch "dogus.k8s.cloudogu.com/${SOURCE_DOGU_NAME}" --type merge -p '{"spec":{"stopped":false,"pauseReconciliation":false}}' >/dev/null
  fi
}

trap cleanup_on_error EXIT

if [ ! -f "${source_db_path}/data.mdb" ]; then
  log "No source LDAP data found, skip migration copy and start target component."
  set_migration_phase "${MIGRATION_PHASE_SKIPPED_NO_SOURCE}"
  scale_target "${TARGET_REPLICAS}"
  log "Step 2 finished successfully (no source data)."
  exit 0
fi

log "Clear target DB directory."
clear_dir_contents "${target_db_path}"

log "Copy source DB data."
mkdir -p "${target_db_path}"
# Keep the component-generated cn=config and migrate only the MDB payload.
# Skip the runtime socket directory; it is recreated by slapd on startup.
find "${source_db_path}" -mindepth 1 -maxdepth 1 ! -name run -exec cp -a {} "${target_db_path}/" \;

if [ ! -f "${target_db_path}/data.mdb" ]; then
  log "Expected target DB file missing after copy: ${target_db_path}/data.mdb"
  exit 1
fi

set_migration_phase "${MIGRATION_PHASE_DONE}"
log "Migration copy finished successfully, starting target component."
scale_target "${TARGET_REPLICAS}"
log "Step 2 finished successfully."
