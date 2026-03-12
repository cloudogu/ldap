#!/bin/sh
set -eu

# shellcheck disable=SC2034
LOG_PREFIX="MIGRATION-STEP1"
# shellcheck source=/scripts/common.sh
# shellcheck disable=SC1091
. /scripts/common.sh

require_env "NAMESPACE"
require_env "COMPONENT_CONFIGMAP_NAME"
require_env "TARGET_STATEFULSET_NAME"
require_env "TARGET_POD_SELECTOR"

cleanup_on_error() {
  rc="$?"
  if [ "${rc}" -ne 0 ]; then
    set +e
    set_migration_phase "${MIGRATION_PHASE_FAILED}"
  fi
}

trap cleanup_on_error EXIT

set_migration_phase "${MIGRATION_PHASE_RUNNING}"

log "Stopping source LDAP dogu '${SOURCE_DOGU_NAME}'."
k patch "dogus.k8s.cloudogu.com/${SOURCE_DOGU_NAME}" --type merge -p '{"spec":{"stopped":true}}' >/dev/null
if ! wait_for_no_pods_by_selector "dogu.name=${SOURCE_DOGU_NAME}"; then
  log "Timed out while waiting for source LDAP dogu pods to stop."
  exit 1
fi

log "Pausing reconciliation for source LDAP dogu '${SOURCE_DOGU_NAME}'."
k patch "dogus.k8s.cloudogu.com/${SOURCE_DOGU_NAME}" --type merge -p '{"spec":{"pauseReconciliation":true}}' >/dev/null

log "Scaling target StatefulSet '${TARGET_STATEFULSET_NAME}' to 0."
k scale "statefulset/${TARGET_STATEFULSET_NAME}" --replicas=0 >/dev/null
target_statefulset_pod_selector="${TARGET_POD_SELECTOR},statefulset.kubernetes.io/pod-name"
if ! wait_for_no_pods_by_selector "${target_statefulset_pod_selector}"; then
  log "Timed out while waiting for target StatefulSet pods to stop."
  exit 1
fi

log "Step 1 finished successfully."
