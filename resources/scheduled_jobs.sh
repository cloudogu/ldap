#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

DEFAULT_MAIL_SENDER_ADDRESS="ldap.dogu@cloudogu.com"

setup_cron() {
  local enabled INTERVAL_MINUTES
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

  doguctl template /crontab.tpl /crontab
  # empty log file on each restart of the Dogu
  : >/tmp/logs/scheduled_jobs.log
  tail -f /tmp/logs/scheduled_jobs.log &

  crontab /crontab

  crond
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

update_pwd_change_notification_user() {
  local mailuser username_from_config
  mailuser="$(getent passwd mailuser || true)"
  if [[ $mailuser == "" ]]; then
    log_debug "create mailuser"
    adduser -D -u 1111 "mailuser"
  else
    log_debug "mailuser already exists"
  fi
  username_from_config="$(get_mail_sender_name "Change password mailer")"
  sed -E -i "s/(mailuser.*:)(.*)(,{3}:.*)/\1${username_from_config}\3/g" /etc/passwd
}

get_mail_sender_name() {
  local default="$1"
  doguctl config --default "${default}" "password_change/mail_sender_name"
}

update_email_sender_alias_mapping() {
  local MAIL_SENDER_ADDRESS
  MAIL_SENDER_ADDRESS=$(doguctl config --default "${DEFAULT_MAIL_SENDER_ADDRESS}" password_change/mail_sender_address)
  if [[ ! "${MAIL_SENDER_ADDRESS}" == "${DEFAULT_MAIL_SENDER_ADDRESS}" && ! "${MAIL_SENDER_ADDRESS}" =~ ^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9.-]+$ ]]; then
    log_error "The configured sender e-mail address seems to be invalid. Falling back to default address: ${DEFAULT_MAIL_SENDER_ADDRESS}"
    MAIL_SENDER_ADDRESS="${DEFAULT_MAIL_SENDER_ADDRESS}"
  fi

  export MAIL_SENDER_ADDRESS
  doguctl template /etc/ssmtp/revaliases.tpl /etc/ssmtp/revaliases
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
