#! /bin/bash
# Bind an unbound BATS variables that fail all tests when combined with 'set -o nounset'
export BATS_TEST_START_TIME="0"
export BATSLIB_FILE_PATH_REM=""
export BATSLIB_FILE_PATH_ADD=""

load '/workspace/target/bats_libs/bats-support/load.bash'
load '/workspace/target/bats_libs/bats-assert/load.bash'
load '/workspace/target/bats_libs/bats-mock/load.bash'
load '/workspace/target/bats_libs/bats-file/load.bash'

setup() {
  export STARTUP_DIR=/workspace/resources
  export TEST_ENV_VAR="test"
  export WORKDIR=/workspace

  adduser="$(mock_create)"
  doguctl="$(mock_create)"
  helper="$(mock_create)"
  sed="$(mock_create)"
  export doguctl
  export adduser
  export helper
  export sed

  export PATH="${PATH}:${BATS_TMPDIR}"

  ln -s "${doguctl}" "${BATS_TMPDIR}/doguctl"
  ln -s "${adduser}" "${BATS_TMPDIR}/adduser"
  ln -s "${helper}" "${BATS_TMPDIR}/helper"
  ln -s "${sed}" "${BATS_TMPDIR}/sed"
}

teardown() {
  unset STARTUP_DIR
  unset WORKDIR
  unset doguctl
  unset adduser
  unset helper
  unset sed
  rm "${BATS_TMPDIR}/doguctl"
  rm "${BATS_TMPDIR}/adduser"
  rm "${BATS_TMPDIR}/helper"
  rm "${BATS_TMPDIR}/sed"
}

@test "log_debug should log a message if the log level is set to DEBUG" {
    source /workspace/resources/scheduled_jobs.sh
    mock_set_output "${doguctl}" "DEBUG" 1

    run log_debug "Test Message"

    assert_success
    assert_line "DEBUG: Test Message"
}

@test "log_debug should log nothing if the log level is set to WARN" {
    source /workspace/resources/scheduled_jobs.sh
    mock_set_output "${doguctl}" "WARN" 1

    run log_debug "Test Message"

    assert_success
    assert_output ""
}

@test "get_mail_sender_name should return the given default value if the key is not set" {
    source /workspace/resources/scheduled_jobs.sh
    mock_set_output "${doguctl}" "the default name" 1

    run get_mail_sender_name "the default name"

    assert_success
    assert_output "the default name"
}

@test "get_mail_sender_name should return the configured value if the key is set" {
    source /workspace/resources/scheduled_jobs.sh
    mock_set_output "${doguctl}" "my change mailer" 1

    run get_mail_sender_name "the default name"

    assert_success
    assert_output "my change mailer"
}

getent() { echo 'user found'; }
sed() { echo "sed called"; }

@test "update_pwd_change_notification_user should not create a new user" {
    source /workspace/resources/scheduled_jobs.sh
    export -f getent
    export -f sed
    mock_set_output "${doguctl}" "DEBUG" 1
    mock_set_output "${doguctl}" "my change mailer" 2

    run update_pwd_change_notification_user "the default name"

    assert_success
    assert_equal "$(mock_get_call_num "${adduser}")" "0"
    assert_line "DEBUG: mailuser already exists"
    assert_line "sed called"
}
