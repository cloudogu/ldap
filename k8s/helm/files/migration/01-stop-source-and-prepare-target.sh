#!/bin/sh
set -eu

# shellcheck disable=SC2034
LOG_PREFIX="MIGRATION-STEP1"
COMMON_SH_PATH="${COMMON_SH_PATH:-/scripts/common.sh}"
# shellcheck source=/scripts/common.sh
# shellcheck disable=SC3046
source "${COMMON_SH_PATH}"

require_env "NAMESPACE"
require_env "COMPONENT_CONFIGMAP_NAME"
require_env "TARGET_STATEFULSET_NAME"
require_env "TARGET_POD_SELECTOR"
require_env "TARGET_GLOBAL_CONFIGMAP_NAME"
require_env "TARGET_GLOBAL_CONFIGMAP_KEY"

cleanup_on_error() {
  rc="$?"
  if [ "${rc}" -ne 0 ]; then
    set +e
    set_migration_phase "${MIGRATION_PHASE_FAILED}"
  fi
}

trap cleanup_on_error EXIT

set_migration_phase "${MIGRATION_PHASE_RUNNING}"

log "Validate source and target LDAP configuration."
validate_migration_configuration "${TARGET_GLOBAL_CONFIGMAP_NAME}" "${TARGET_GLOBAL_CONFIGMAP_KEY}"

log "Stopping source LDAP dogu '${SOURCE_DOGU_NAME}'."
kns patch "dogus.k8s.cloudogu.com/${SOURCE_DOGU_NAME}" --type merge -p '{"spec":{"stopped":true}}' >/dev/null
if ! wait_for_no_pods_by_selector "dogu.name=${SOURCE_DOGU_NAME}"; then
  log "Timed out while waiting for source LDAP dogu pods to stop."
  exit 1
fi

log "Pausing reconciliation for source LDAP dogu '${SOURCE_DOGU_NAME}'."
kns patch "dogus.k8s.cloudogu.com/${SOURCE_DOGU_NAME}" --type merge -p '{"spec":{"pauseReconciliation":true}}' >/dev/null

log "Scaling target StatefulSet '${TARGET_STATEFULSET_NAME}' to 0."
scale_target 0
target_statefulset_pod_selector="${TARGET_POD_SELECTOR},statefulset.kubernetes.io/pod-name"
if ! wait_for_no_pods_by_selector "${target_statefulset_pod_selector}"; then
  log "Timed out while waiting for target StatefulSet pods to stop."
  exit 1
fi

log "Step 1 finished successfully."
