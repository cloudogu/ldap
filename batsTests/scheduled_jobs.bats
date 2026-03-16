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
  # Create directories needed by the script BEFORE we mock commands like mkdir
  mkdir -p "${BATS_TMPDIR}/logs"
  touch "${BATS_TMPDIR}/crontab"

  export STARTUP_DIR=/workspace/resources
  export WORKDIR=/workspace

  doguctl="$(mock_create)"
  export doguctl
  supercronic="$(mock_create)"
  export supercronic
  tail="$(mock_create)"
  export tail
  truncate="$(mock_create)"
  export truncate
  mkdir="$(mock_create)"
  export mkdir

  export PATH="${BATS_TMPDIR}:${PATH}"

  ln -s "${doguctl}" "${BATS_TMPDIR}/doguctl"
  ln -s "${supercronic}" "${BATS_TMPDIR}/supercronic"
  ln -s "${tail}" "${BATS_TMPDIR}/tail"
  ln -s "${truncate}" "${BATS_TMPDIR}/truncate"
  ln -s "${mkdir}" "${BATS_TMPDIR}/mkdir"
}

teardown() {
  unset STARTUP_DIR
  unset WORKDIR
  unset doguctl
  unset supercronic
  unset tail
  unset truncate
  unset mkdir
  rm "${BATS_TMPDIR}/doguctl"
  rm "${BATS_TMPDIR}/supercronic"
  rm "${BATS_TMPDIR}/tail"
  rm "${BATS_TMPDIR}/truncate"
  rm "${BATS_TMPDIR}/mkdir"
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

@test "parse_cron_interval should return * for interval 1" {
    source /workspace/resources/scheduled_jobs.sh
    mock_set_output "${doguctl}" "1" 1

    run parse_cron_interval

    assert_success
    assert_line "*"
}

@test "parse_cron_interval should return 0 for interval 60" {
    source /workspace/resources/scheduled_jobs.sh
    mock_set_output "${doguctl}" "60" 1

    run parse_cron_interval

    assert_success
    assert_line "0"
}

@test "parse_cron_interval should return */15 for interval 15" {
    source /workspace/resources/scheduled_jobs.sh
    mock_set_output "${doguctl}" "15" 1

    run parse_cron_interval

    assert_success
    assert_line "*/15"
}

@test "parse_cron_interval should return <invalid> for interval 99" {
    source /workspace/resources/scheduled_jobs.sh
    mock_set_output "${doguctl}" "99" 1

    run parse_cron_interval

    assert_success
    assert_line "<invalid>"
}

@test "setup_cron should do nothing if notification_enabled is false" {
    source /workspace/resources/scheduled_jobs.sh
    mock_set_output "${doguctl}" "false" 1

    run setup_cron

    assert_success
    assert_line "INFO: e-mail notification is disabled"
    assert_equal "$(mock_get_call_num "${supercronic}")" "0"
}

@test "setup_cron should start supercronic if enabled" {
    source /workspace/resources/scheduled_jobs.sh
    
    # Overwrite vars from SUT to point to our test directories
    CRONTAB_FILE="${BATS_TMPDIR}/crontab"
    LOG_DIR="${BATS_TMPDIR}/logs"
    LOG_FILE="${LOG_DIR}/scheduled_jobs.log"

    # Set default success status for ALL calls of ALL mocks
    for m in "${doguctl}" "${supercronic}" "${mkdir}" "${truncate}" "${tail}"; do
      mock_set_status "${m}" 0
    done

    # Configure specific outputs for doguctl
    # Call 1: notification_enabled check
    mock_set_output "${doguctl}" "true" 1
    # Call 2: interval check (inside parse_cron_interval)
    mock_set_output "${doguctl}" "15" 2
    # Call 3: template command (no output needed, just status 0)

    run setup_cron

    assert_success
    assert_line "use crontab setting */15 * * * *"
    
    # Verify supercronic was called twice
    assert_equal "$(mock_get_call_num "${supercronic}")" "2"
    
    # Call 1: -test ...
    assert_equal "$(mock_get_call_args "${supercronic}" "1")" "-test ${CRONTAB_FILE}"
    # Call 2: -quiet -no-reap ...
    assert_equal "$(mock_get_call_args "${supercronic}" "2")" "-quiet -no-reap ${CRONTAB_FILE}"
}
