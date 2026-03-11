#!/bin/sh
set -eu

# shellcheck disable=SC2034
LOG_PREFIX="MIGRATION-STEP2"
# shellcheck source=/scripts/common.sh
# shellcheck disable=SC1091
. /scripts/common.sh

require_env "NAMESPACE"
require_env "TARGET_STATEFULSET_NAME"
require_env "TARGET_REPLICAS"
require_env "SOURCE_VOLUME_PATH"
require_env "TARGET_VOLUME_PATH"

source_db_path="${SOURCE_VOLUME_PATH}/${SOURCE_DB_SUBPATH}"
source_config_path="${SOURCE_VOLUME_PATH}/${SOURCE_CONFIG_SUBPATH}"
target_db_path="${TARGET_VOLUME_PATH}/${TARGET_DB_SUBPATH}"
target_config_path="${TARGET_VOLUME_PATH}/${TARGET_CONFIG_SUBPATH}"

if is_migration_done; then
  log "Migration marker already exists, ensure component is started."
  scale_target "${TARGET_REPLICAS}"
  exit 0
fi

cleanup_on_error() {
  rc="$?"
  if [ "${rc}" -ne 0 ]; then
    set +e
    log "Step 2 failed with exit code ${rc}."
    log "Restart source LDAP dogu '${SOURCE_DOGU_NAME}'."
    k patch "dogus.k8s.cloudogu.com/${SOURCE_DOGU_NAME}" --type merge -p '{"spec":{"stopped":false}}' >/dev/null
  fi
}

trap cleanup_on_error EXIT

has_source_db=0
has_source_config=0

if [ -f "${source_db_path}/data.mdb" ]; then
  has_source_db=1
fi
if [ -d "${source_config_path}/cn=config" ]; then
  has_source_config=1
fi

if [ "${has_source_db}" -eq 0 ] && [ "${has_source_config}" -eq 0 ]; then
  log "No source LDAP data found, skip migration copy and start target component."
  write_migration_marker "skipped_no_source"
  scale_target "${TARGET_REPLICAS}"
  log "Step 2 finished successfully (no source data)."
  exit 0
fi

if [ "${has_source_db}" -eq 0 ]; then
  log "Source DB file missing: ${source_db_path}/data.mdb"
  exit 1
fi
if [ "${has_source_config}" -eq 0 ]; then
  log "Source config path does not contain cn=config: ${source_config_path}/cn=config"
  exit 1
fi

log "Clear target DB/config directories."
clear_dir_contents "${target_db_path}"
clear_dir_contents "${target_config_path}"

log "Copy source DB data."
cp -a "${source_db_path}/." "${target_db_path}/"

log "Copy source config data."
cp -a "${source_config_path}/." "${target_config_path}/"

if [ ! -f "${target_db_path}/data.mdb" ]; then
  log "Expected target DB file missing after copy: ${target_db_path}/data.mdb"
  exit 1
fi
if [ ! -d "${target_config_path}/cn=config" ]; then
  log "Expected target config directory missing after copy: ${target_config_path}/cn=config"
  exit 1
fi

write_migration_marker "migrated"
log "Migration copy finished successfully, starting target component."
scale_target "${TARGET_REPLICAS}"
log "Step 2 finished successfully."
