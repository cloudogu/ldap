#!/bin/sh

# Fixed migration constants.
# shellcheck disable=SC2034
SOURCE_DOGU_NAME="ldap"
WAIT_TIMEOUT_SECONDS="${WAIT_TIMEOUT_SECONDS:-300}"
SOURCE_DB_SUBPATH="db"
SOURCE_CONFIG_SUBPATH="config"
TARGET_DB_SUBPATH="db"
TARGET_CONFIG_SUBPATH="config"
MIGRATION_MARKER_FILENAME=".ldap-component-migration-done"

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

select_running_source_pod() {
  k get pods -l "dogu.name=${SOURCE_DOGU_NAME}" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}' \
    | awk '$2=="Running" || $2=="Pending"{print $1; exit}'
}

migration_marker_path() {
  printf '%s/%s' "${TARGET_VOLUME_PATH}" "${MIGRATION_MARKER_FILENAME}"
}

is_migration_done() {
  marker_file="$(migration_marker_path)"
  [ -f "${marker_file}" ]
}

write_migration_marker() {
  marker_file="$(migration_marker_path)"
  mkdir -p "$(dirname "${marker_file}")"
  {
    printf 'version=1\n'
    printf 'created_at_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'release=%s\n' "${RELEASE_NAME:-unknown}"
    printf 'namespace=%s\n' "${NAMESPACE:-unknown}"
    printf 'reason=%s\n' "${1:-migrated}"
  } > "${marker_file}"
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
