#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

function setup_cron() {
  echo "setting up cronjob"

  local config_interval_minutes INTERVAL_MINUTES minutes_regex='^([0-9]|[1-5][0-9])?$'
  config_interval_minutes="$(doguctl config --default "1" "password_change/check_interval_minutes")"

  if [[ "${config_interval_minutes}" == "0" ]]; then # every hour
     INTERVAL_MINUTES="${config_interval_minutes}"
  elif  [[ "${config_interval_minutes}" == "1" ]]; then # every minute
     INTERVAL_MINUTES="*"
  elif [[ "${config_interval_minutes}" =~ ${minutes_regex} ]]; then # every x minutes
    INTERVAL_MINUTES="*/${config_interval_minutes}"
  else
    echo "error: wrong value for configuration entry password_change_check_interval_minutes: allowed values are numbers between 0 and 59" >&2
    exit 1
  fi
  echo "use crontab setting ${INTERVAL_MINUTES} * * * *"
  export INTERVAL_MINUTES

  doguctl template /crontab.tpl /crontab
  # empty log file on each restart of the Dogu
  touch /tmp/logs/scheduled_jobs.log
  tail -f /tmp/logs/scheduled_jobs.log &

  crontab /crontab

  crond
}

function update_pwd_change_notification_user() {
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

function get_mail_sender_name() {
  local default="$1"
  doguctl config --default "${default}" "password_change/mail_sender_name"
}

function log_debug() {
  log_level="$(doguctl config --default "WARN" "logging/root")"
  if [[ "${log_level}" == "DEBUG" ]]; then
    message="$1"
    echo "DEBUG: ${message}"
  fi
}