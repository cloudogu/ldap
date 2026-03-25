#!/bin/sh

# Fixed migration constants.
# shellcheck disable=SC2034
SOURCE_DOGU_NAME="ldap"
SOURCE_DOGU_CONFIGMAP_NAME="ldap-config"
SOURCE_DOGU_CONFIGMAP_KEY="config.yaml"
SOURCE_GLOBAL_CONFIGMAP_NAME="global-config"
SOURCE_GLOBAL_CONFIGMAP_KEY="config.yaml"
DEFAULT_OPENLDAP_SUFFIX="dc=cloudogu,dc=com"
WAIT_TIMEOUT_SECONDS="${WAIT_TIMEOUT_SECONDS:-300}"
RETRY_ATTEMPTS="${RETRY_ATTEMPTS:-3}"
RETRY_DELAY_SECONDS="${RETRY_DELAY_SECONDS:-2}"
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

kns() {
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

get_configmap_data() {
  configmap_name="$1"
  configmap_key="$2"
  kns get "configmap/${configmap_name}" -o "go-template={{ index .data \"$configmap_key\" }}" 2>/dev/null || true
}

# extract_yaml_scalar expects a YAML key-value string in the format 'key: "value"\n' and returns the value without quotes. The newline is strictly required for "read" to succeed.
extract_yaml_scalar() {
  yaml_key="$1"

  # plain top-level lines like `domain: example.com` or `openldap_suffix: "dc=example,dc=com"`.
  while IFS= read -r line; do
    case "${line}" in
      "${yaml_key}":*)
        # Drop everything through the first ":" to keep only the scalar value.
        value="${line#*:}"
        # Trim surrounding whitespace after the ":".
        value="$(printf '%s' "${value}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"

        # Remove one pair of surrounding quotes when the scalar is wrapped as
        # "value" or 'value'. Inner quotes remain untouched.
         case "${value}" in
           \"*\") value="${value#\"}"; value="${value%\"}" ;;
           \'*\') value="${value#\'}"; value="${value%\'}" ;;
         esac

        printf '%s\n' "${value}"
        return 0
        ;;
    esac
  done
}

validate_migration_configuration() {
  target_global_configmap_name="$1"
  target_global_configmap_key="$2"

  source_dogu_config_yaml="$(get_configmap_data "${SOURCE_DOGU_CONFIGMAP_NAME}" "${SOURCE_DOGU_CONFIGMAP_KEY}")"
  if [ -z "${source_dogu_config_yaml}" ]; then
    log "Source dogu config '${SOURCE_DOGU_CONFIGMAP_NAME}/${SOURCE_DOGU_CONFIGMAP_KEY}' not found, skip migration config validation."
    return 0
  fi

  target_component_config_yaml="$(get_configmap_data "${COMPONENT_CONFIGMAP_NAME}" "config.yaml")"
  if [ -z "${target_component_config_yaml}" ]; then
    log "Target component config '${COMPONENT_CONFIGMAP_NAME}/config.yaml' not found."
    return 1
  fi

  source_openldap_suffix="$(printf '%s\n' "${source_dogu_config_yaml}" | extract_yaml_scalar "openldap_suffix")"
  target_openldap_suffix="$(printf '%s\n' "${target_component_config_yaml}" | extract_yaml_scalar "openldap_suffix")"
  source_openldap_suffix="${source_openldap_suffix:-$DEFAULT_OPENLDAP_SUFFIX}"
  target_openldap_suffix="${target_openldap_suffix:-$DEFAULT_OPENLDAP_SUFFIX}"

  source_global_config_yaml="$(get_configmap_data "${SOURCE_GLOBAL_CONFIGMAP_NAME}" "${SOURCE_GLOBAL_CONFIGMAP_KEY}")"
  if [ -z "${source_global_config_yaml}" ]; then
    log "Source global config '${SOURCE_GLOBAL_CONFIGMAP_NAME}/${SOURCE_GLOBAL_CONFIGMAP_KEY}' not found."
    return 1
  fi

  target_global_config_yaml="$(get_configmap_data "${target_global_configmap_name}" "${target_global_configmap_key}")"
  if [ -z "${target_global_config_yaml}" ]; then
    log "Target global config '${target_global_configmap_name}/${target_global_configmap_key}' not found."
    return 1
  fi

  source_domain="$(printf '%s\n' "${source_global_config_yaml}" | extract_yaml_scalar "domain")"
  target_domain="$(printf '%s\n' "${target_global_config_yaml}" | extract_yaml_scalar "domain")"
  if [ -z "${source_domain}" ] || [ -z "${target_domain}" ]; then
    log "Migration config validation failed: unable to resolve 'domain' for source='${source_domain}' or target='${target_domain}'."
    return 1
  fi

  if [ "${source_domain}" != "${target_domain}" ]; then
    log "Migration config validation failed: domain mismatch (dogu='${source_domain}', component='${target_domain}')."
    return 1
  fi

  if [ "${source_openldap_suffix}" != "${target_openldap_suffix}" ]; then
    log "Migration config validation failed: openldap_suffix mismatch (dogu='${source_openldap_suffix}', component='${target_openldap_suffix}')."
    return 1
  fi

  log "Migration config validation succeeded for domain='${target_domain}' and openldap_suffix='${target_openldap_suffix}'."
}

get_migration_phase() {
  kns get "configmap/${COMPONENT_CONFIGMAP_NAME}" -o jsonpath='{.data.migrationPhase}' 2>/dev/null || true
}

retry_command() {
  attempt=1
  while [ "${attempt}" -le "${RETRY_ATTEMPTS}" ]; do
# expand the given arguments, execute it, and evaluate the exit code.
    if "$@"; then
      return 0
    fi

    if [ "${attempt}" -lt "${RETRY_ATTEMPTS}" ]; then
      log "Command failed (attempt ${attempt}/${RETRY_ATTEMPTS}), retrying in ${RETRY_DELAY_SECONDS}s: $*"
      sleep "${RETRY_DELAY_SECONDS}"
    fi

    attempt="$(( attempt + 1 ))"
  done

  log "Command failed after ${RETRY_ATTEMPTS} attempts: $*"
  return 1
}

set_migration_phase() {
  phase="$1"
  retry_command kns patch "configmap/${COMPONENT_CONFIGMAP_NAME}" --type merge \
    -p "{\"data\":{\"migrationPhase\":\"${phase}\"}}" >/dev/null
}

wait_for_no_pods_by_selector() {
  selector="$1"
  end_time="$(( $(date +%s) + WAIT_TIMEOUT_SECONDS ))"
  while [ "$(date +%s)" -lt "${end_time}" ]; do
    # jsonpath prints the phase of each matching pod.
    # {"\n"} adds a line break after every phase so grep can count one pod state per line.
    # grep exits with 1 when it finds no Running/Pending pods;
    # `|| true` converts that expected "no matches" case into a zero count instead of aborting the script.
    active_count="$(kns get pods -l "${selector}" -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' \
      | grep -Ec 'Running|Pending' || true)"
    if [ "${active_count}" -eq 0 ]; then
      log "No active pods remain for selector '${selector}'."
      return 0
    fi
    log "Waiting for pods with selector '${selector}' to stop. Active pods: ${active_count}."
    sleep 2
  done
  log "Timed out while waiting for pods with selector '${selector}' to stop."
  return 1
}

scale_target() {
  replicas="$1"
  retry_command kns scale "statefulset/${TARGET_STATEFULSET_NAME}" --replicas="${replicas}" >/dev/null
}

clear_dir_contents() {
  dir_path="$1"
  mkdir -p "${dir_path}"
  find "${dir_path}" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
}
