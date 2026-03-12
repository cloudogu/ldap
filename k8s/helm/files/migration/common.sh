#!/bin/sh

# Fixed migration constants.
# shellcheck disable=SC2034
SOURCE_DOGU_NAME="ldap"
WAIT_TIMEOUT_SECONDS="${WAIT_TIMEOUT_SECONDS:-300}"
SOURCE_DB_SUBPATH="db"
TARGET_DB_SUBPATH="db"
MIGRATION_PHASE_PENDING="pending"
MIGRATION_PHASE_RUNNING="running"
MIGRATION_PHASE_DONE="done"
MIGRATION_PHASE_FAILED="failed"
MIGRATION_PHASE_SKIPPED_NO_SOURCE="skipped_no_source"

log() {
  echo "[${LOG_PREFIX:-MIGRATION}] $*"
}

k() {
  kubectl -n "${NAMESPACE}" "$@"
}

require_env() {
  var_name="$1"
  eval "var_value=\${${var_name}:-}"
  if [ -z "${var_value}" ]; then
    echo "required environment variable '${var_name}' is missing" >&2
    exit 1
  fi
}

get_migration_phase() {
  k get "configmap/${COMPONENT_CONFIGMAP_NAME}" -o jsonpath='{.data.migrationPhase}' 2>/dev/null || true
}

set_migration_phase() {
  phase="$1"
  k patch "configmap/${COMPONENT_CONFIGMAP_NAME}" --type merge \
    -p "{\"data\":{\"migrationPhase\":\"${phase}\"}}" >/dev/null
}

wait_for_no_pods_by_selector() {
  selector="$1"
  end_time="$(( $(date +%s) + WAIT_TIMEOUT_SECONDS ))"
  while [ "$(date +%s)" -lt "${end_time}" ]; do
    active_count="$(k get pods -l "${selector}" -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' \
      | grep -Ec 'Running|Pending' || true)"
    if [ "${active_count}" -eq 0 ]; then
      return 0
    fi
    sleep 2
  done
  return 1
}

scale_target() {
  replicas="$1"
  k scale "statefulset/${TARGET_STATEFULSET_NAME}" --replicas="${replicas}" >/dev/null
}

clear_dir_contents() {
  dir_path="$1"
  mkdir -p "${dir_path}"
  find "${dir_path}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
}
