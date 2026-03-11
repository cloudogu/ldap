#!/bin/sh
set -eu

# shellcheck disable=SC2034
LOG_PREFIX="MIGRATION-STEP1"
# shellcheck source=/scripts/common.sh
# shellcheck disable=SC1091
. /scripts/common.sh

require_env "NAMESPACE"
require_env "TARGET_STATEFULSET_NAME"
require_env "TARGET_POD_SELECTOR"

source_pod="$(select_running_source_pod)"
if [ -z "${source_pod}" ]; then
  log "No running source LDAP dogu pod found, migration is not required."
  exit 0
fi

log "Stopping source LDAP dogu '${SOURCE_DOGU_NAME}'."
k patch "dogus.k8s.cloudogu.com/${SOURCE_DOGU_NAME}" --type merge -p '{"spec":{"stopped":true}}' >/dev/null
if ! wait_for_no_pods_by_selector "dogu.name=${SOURCE_DOGU_NAME}"; then
  log "Timed out while waiting for source LDAP dogu pods to stop."
  exit 1
fi

log "Scaling target StatefulSet '${TARGET_STATEFULSET_NAME}' to 0."
k scale "statefulset/${TARGET_STATEFULSET_NAME}" --replicas=0 >/dev/null
if ! wait_for_no_pods_by_selector "${TARGET_POD_SELECTOR}"; then
  log "Timed out while waiting for target component pods to stop."
  exit 1
fi

log "Step 1 finished successfully."
