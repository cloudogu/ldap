#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

setup_cron() {
  local enabled INTERVAL_MINUTES CRONTAB_FILE LOG_DIR LOG_FILE
  enabled="$(doguctl config --default "true" "password_change/notification_enabled")"
  if [[ "${enabled}" == "false" ]]; then
    echo "INFO: e-mail notification is disabled"
    return
  fi

  INTERVAL_MINUTES="$(parse_cron_interval)"
  if [[ "${INTERVAL_MINUTES}" == "<invalid>" ]]; then
    log_error "wrong value for configuration entry password_change_check_interval_minutes: allowed values are numbers between 1 and 60"
    log_error "using default value 1 as fallback"
    INTERVAL_MINUTES="*"
  fi
  echo "use crontab setting ${INTERVAL_MINUTES} * * * *"
  export INTERVAL_MINUTES

  CRONTAB_FILE="/tmp/crontab"
  LOG_DIR="/tmp/logs"
  LOG_FILE="${LOG_DIR}/scheduled_jobs.log"
  doguctl template /crontab.tpl "${CRONTAB_FILE}"
  mkdir -p "${LOG_DIR}"
  # empty log file on each restart of the Dogu
  truncate -s 0 "${LOG_FILE}"
  tail -f "${LOG_FILE}" &

  # supercronic is part of the image and is the only supported scheduler here.
  if ! supercronic -test "${CRONTAB_FILE}" >/dev/null 2>&1; then
    log_error "generated crontab is invalid; cannot start scheduler"
    return 1
  fi

  supercronic -quiet -no-reap "${CRONTAB_FILE}" >>"${LOG_FILE}" 2>&1 &
}

parse_cron_interval() {
  # regex to verify 1-9 or 10-59 or 60
  local config_interval_minutes INTERVAL_MINUTES minutes_regex='^([1-9]|[1-5][0-9]|60)?$'
  config_interval_minutes="$(doguctl config --default "1" "password_change/check_interval_minutes")"

  if [[ "${config_interval_minutes}" == "60" ]]; then # every hour
    INTERVAL_MINUTES="0"
  elif [[ "${config_interval_minutes}" == "1" ]]; then # every minute
    INTERVAL_MINUTES="*"
  elif [[ "${config_interval_minutes}" =~ ${minutes_regex} ]]; then # every x minutes
    INTERVAL_MINUTES="*/${config_interval_minutes}"
  else
    INTERVAL_MINUTES="<invalid>"
  fi
  echo "${INTERVAL_MINUTES}"
}

log_debug() {
  local log_level
  log_level="$(doguctl config --default "WARN" "logging/root")"
  if [[ "${log_level}" == "DEBUG" ]]; then
    message="$1"
    echo "DEBUG: ${message}"
  fi
}

log_error() {
  message="$1"
  echo "ERROR: ${message}"
}
