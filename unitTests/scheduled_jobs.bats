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
  export WORKDIR=/workspace

  doguctl="$(mock_create)"
  export doguctl

  export PATH="${PATH}:${BATS_TMPDIR}"

  ln -s "${doguctl}" "${BATS_TMPDIR}/doguctl"
}

teardown() {
  unset STARTUP_DIR
  unset WORKDIR
  unset doguctl
  rm "${BATS_TMPDIR}/doguctl"
}

@test "log_debug should log a message if the log level is set to DEBUG" {
    source /workspace/resources/scheduled_jobs.sh
    mock_set_output "${doguctl}" "DEBUG" 1

    run log_debug "Test Message"

    assert_success
    assert_line "DEBUG: Test Message"
}

@test "log_debug should log nothing if the log level is set to WARN" {
#    source /workspace/resources/scheduled_jobs.sh
#    mock_set_output "${doguctl}" "WARN" 1

#    run log_debug "Test Message"

#    assert_success
#    assert_output ""
}
