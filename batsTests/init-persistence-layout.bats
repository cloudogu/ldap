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
    mkdir_mock="$(mock_create)"
    chown_mock="$(mock_create)"
    chmod_mock="$(mock_create)"
    cp_mock="$(mock_create)"

    # Environment for the script (no longer used by script, but we keep it to know the expected paths)
    expected_persistence_dir="/persistence"
    expected_openldap_etc_dir="/openldap-etc"
    expected_dogu_json_file="/dogu.json"
    expected_ces_dogu_json_dir="/ces-dogu-json"
    export HOSTNAME="test-host"

    # We cannot create files at /persistence etc. in the test container's root filesystem.
    # But since we MOCK mkdir, cp, etc., the script won't actually try to write there.
    # However, 'sed' and 'head' are NOT mocked.
    # Let's mock 'sed' and 'head' to handle the /dogu.json path.
    sed_mock="$(mock_create)"
    head_mock="$(mock_create)"
    ln -s "${sed_mock}" "${BATS_TMPDIR}/sed"
    ln -s "${head_mock}" "${BATS_TMPDIR}/head"

    export PATH="${BATS_TMPDIR}:${PATH}"
    ln -s "${mkdir_mock}" "${BATS_TMPDIR}/mkdir"
    ln -s "${chown_mock}" "${BATS_TMPDIR}/chown"
    ln -s "${chmod_mock}" "${BATS_TMPDIR}/chmod"
    ln -s "${cp_mock}" "${BATS_TMPDIR}/cp"
}

teardown() {
    rm "${BATS_TMPDIR}/mkdir"
    rm "${BATS_TMPDIR}/chown"
    rm "${BATS_TMPDIR}/chmod"
    rm "${BATS_TMPDIR}/cp"
    rm "${BATS_TMPDIR}/sed"
    rm "${BATS_TMPDIR}/head"
}

@test "init_persistence_layout should succeed in happy path" {
    source /workspace/resources/component/init-persistence-layout.sh

    # --- Arrange ---
    mock_set_status "${mkdir_mock}" 0
    mock_set_status "${chown_mock}" 0
    mock_set_status "${chmod_mock}" 0
    mock_set_status "${cp_mock}" 0
    mock_set_output "${sed_mock}" "1.2.3"
    mock_set_status "${sed_mock}" 0
    mock_set_output "${head_mock}" "1.2.3"
    mock_set_status "${head_mock}" 0

    # --- Act ---
    run init_persistence_layout

    # --- Assert ---
    assert_success
    
    # Check mkdir calls
    assert_equal "$(mock_get_call_num "${mkdir_mock}")" "2"
    assert_equal "$(mock_get_call_args "${mkdir_mock}" 1)" "-p /persistence/db /persistence/config /persistence/local-config"
    assert_equal "$(mock_get_call_args "${mkdir_mock}" 2)" "-p /ces-dogu-json/test-host"

    # Check chown calls
    assert_equal "$(mock_get_call_num "${chown_mock}")" "2"
    assert_equal "$(mock_get_call_args "${chown_mock}" 1)" "-R 100:101 /persistence/db /persistence/config /persistence/local-config"
    assert_equal "$(mock_get_call_args "${chown_mock}" 2)" "-R 100:101 /ces-dogu-json"

    # Check cp calls
    assert_equal "$(mock_get_call_num "${cp_mock}")" "2"
    assert_equal "$(mock_get_call_args "${cp_mock}" 1)" "-a /etc/openldap/. /openldap-etc/"
    assert_equal "$(mock_get_call_args "${cp_mock}" 2)" "/dogu.json /ces-dogu-json/test-host/1.2.3"
}

@test "init_persistence_layout should fallback to chmod if chown fails for persistence" {
    source /workspace/resources/component/init-persistence-layout.sh

    # --- Arrange ---
    mock_set_status "${mkdir_mock}" 0
    mock_set_status "${chown_mock}" 1 1 # fail first call (persistence)
    mock_set_status "${chown_mock}" 0 2 # succeed second call
    mock_set_status "${chmod_mock}" 0
    mock_set_status "${cp_mock}" 0
    mock_set_output "${sed_mock}" "1.2.3"
    mock_set_status "${sed_mock}" 0
    mock_set_output "${head_mock}" "1.2.3"
    mock_set_status "${head_mock}" 0

    # --- Act ---
    run init_persistence_layout

    # --- Assert ---
    assert_success
    assert_line "WARN: chown for persistence dirs failed; falling back to u+rwX,g+rwX permissions."
    
    # Verify chmod was called
    assert_equal "$(mock_get_call_num "${chmod_mock}")" "2" # Once for fallback, once for openldap-etc
    assert_equal "$(mock_get_call_args "${chmod_mock}" 1)" "-R u+rwX,g+rwX,o-rwx /persistence/db /persistence/config /persistence/local-config"
}

@test "init_persistence_layout should fail if DOGU_VERSION cannot be determined" {
    source /workspace/resources/component/init-persistence-layout.sh

    # --- Arrange ---
    mock_set_status "${mkdir_mock}" 0
    mock_set_status "${chown_mock}" 0
    mock_set_status "${cp_mock}" 0
    # Mock sed to return empty string for version
    mock_set_output "${sed_mock}" ""
    mock_set_status "${sed_mock}" 0
    mock_set_output "${head_mock}" ""
    mock_set_status "${head_mock}" 0

    # --- Act ---
    run init_persistence_layout

    # --- Assert ---
    assert_failure
    assert_line "unable to determine dogu version from /dogu.json"
}

@test "init_persistence_layout should log warning if chown fails for ces-dogu-json but continue" {
    source /workspace/resources/component/init-persistence-layout.sh

    # --- Arrange ---
    mock_set_status "${mkdir_mock}" 0
    mock_set_status "${chown_mock}" 0 1 # succeed first call
    mock_set_status "${chown_mock}" 1 2 # fail second call (ces-dogu-json)
    mock_set_status "${chmod_mock}" 0
    mock_set_status "${cp_mock}" 0
    mock_set_output "${sed_mock}" "1.2.3"
    mock_set_status "${sed_mock}" 0
    mock_set_output "${head_mock}" "1.2.3"
    mock_set_status "${head_mock}" 0

    # --- Act ---
    run init_persistence_layout

    # --- Assert ---
    assert_success
    assert_line "WARN: chown for /ces-dogu-json failed; continuing because files are read-only metadata for the runtime container."
}
