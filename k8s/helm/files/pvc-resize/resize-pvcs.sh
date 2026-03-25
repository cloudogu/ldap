#!/bin/sh
set -eu

log() {
  echo "[PVC-RESIZE] $*"
}

require_env() {
  var_name="$1"
  eval "var_value=\${${var_name}:-}"
  if [ -z "${var_value}" ]; then
    echo "required environment variable '${var_name}' is missing" >&2
    exit 1
  fi
}

patch_pvc_size() {
  pvc_name="$1"

  kubectl -n "${NAMESPACE}" patch pvc "${pvc_name}" --type merge \
    -p "{\"spec\":{\"resources\":{\"requests\":{\"storage\":\"${TARGET_SIZE}\"}}}}"
}

require_env "NAMESPACE"
require_env "PVC_SELECTOR"
require_env "TARGET_SIZE"

pvc_names="$(kubectl -n "${NAMESPACE}" get pvc -l "${PVC_SELECTOR}" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')"
if [ -z "${pvc_names}" ]; then
  log "No PVCs found for selector '${PVC_SELECTOR}'. Nothing to resize."
  exit 0
fi

for pvc_name in ${pvc_names}; do
  log "Ensure PVC '${pvc_name}' requests ${TARGET_SIZE}."
  if output="$(patch_pvc_size "${pvc_name}" 2>&1)"; then
    log "PVC '${pvc_name}' patched successfully."
    continue
  fi

  case "${output}" in
    *"field can not be less than previous value"*)
      log "PVC '${pvc_name}' is already larger than target ${TARGET_SIZE}. Skip shrinking."
      ;;
    *)
      echo "${output}" >&2
      exit 1
      ;;
  esac
done

log "done checking PVCs for resizing."
