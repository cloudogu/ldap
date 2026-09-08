#! /bin/bash
export BATS_TEST_START_TIME="0"
export BATSLIB_FILE_PATH_REM=""
export BATSLIB_FILE_PATH_ADD=""

load '/workspace/target/bats_libs/bats-support/load.bash'
load '/workspace/target/bats_libs/bats-assert/load.bash'
load '/workspace/target/bats_libs/bats-mock/load.bash'
load '/workspace/target/bats_libs/bats-file/load.bash'

setup() {
    # 'sed' is deliberately NOT mocked - extractDNs needs the real one.
    ldapsearch="$(mock_create)"
    ldapmodify="$(mock_create)"
    slappasswd="$(mock_create)"
    doguctl="$(mock_create)"

    export PATH="${BATS_TMPDIR}:${PATH}"
    ln -s "${ldapsearch}" "${BATS_TMPDIR}/ldapsearch"
    ln -s "${ldapmodify}" "${BATS_TMPDIR}/ldapmodify"
    ln -s "${slappasswd}" "${BATS_TMPDIR}/slappasswd"
    ln -s "${doguctl}" "${BATS_TMPDIR}/doguctl"

    # The script reads this from the environment, exported by startup.sh
    export OPENLDAP_SUFFIX="dc=cloudogu,dc=com"

    backendDN="olcDatabase={1}mdb,cn=config"
    capturedLdif="${BATS_TMPDIR}/captured.ldif"
}

teardown() {
    rm "${BATS_TMPDIR}/ldapsearch"
    rm "${BATS_TMPDIR}/ldapmodify"
    rm "${BATS_TMPDIR}/slappasswd"
    rm "${BATS_TMPDIR}/doguctl"
    rm -f "${capturedLdif}"
}

@test "extractDNs should strip the 'dn: ' prefix" {
    source /workspace/resources/rotate-root-password.sh

    run extractDNs "dn: olcDatabase={1}mdb,cn=config"

    assert_success
    assert_output "olcDatabase={1}mdb,cn=config"
}

@test "extractDNs should ignore every line that is not a dn" {
    source /workspace/resources/rotate-root-password.sh

    run extractDNs "dn: olcDatabase={1}mdb,cn=config
objectClass: olcMdbConfig
olcSuffix: dc=cloudogu,dc=com
olcRootDN: cn=admin,dc=cloudogu,dc=com"

    assert_success
    assert_output "olcDatabase={1}mdb,cn=config"
}

@test "findBackendDatabaseDN should search cn=config filtered by the configured suffix" {
    source /workspace/resources/rotate-root-password.sh

    mock_set_output "${ldapsearch}" "dn: ${backendDN}"

    run findBackendDatabaseDN

    assert_success
    assert_output "${backendDN}"

    run mock_get_call_args "${ldapsearch}" 1
    assert_output --partial "-b cn=config"
    assert_output --partial "(olcSuffix=dc=cloudogu,dc=com)"
}

@test "applyRootPassword should skip the rotation when no backend database is found" {
    source /workspace/resources/rotate-root-password.sh

    mock_set_output "${ldapsearch}" ""

    run applyRootPassword

    assert_success
    assert_line --partial "WARN: no backend database found for suffix 'dc=cloudogu,dc=com'"
    assert_equal "$(mock_get_call_num "${slappasswd}")" "0"
    assert_equal "$(mock_get_call_num "${ldapmodify}")" "0"
}

@test "applyRootPassword should use a configured rootpwd instead of generating one" {
    source /workspace/resources/rotate-root-password.sh

    mock_set_output "${ldapsearch}" "dn: ${backendDN}"
    mock_set_output "${doguctl}" "configured-secret"
    mock_set_status "${doguctl}" 0

    run applyRootPassword

    assert_success
    assert_line --partial "Applying the configured 'rootpwd'"
    assert_line --partial "olcRootPW successfully set from configured source"

    # 'doguctl config' only - no second call, so 'doguctl random' never ran
    assert_equal "$(mock_get_call_num "${doguctl}")" "1"
    assert_equal "$(mock_get_call_args "${doguctl}" 1)" "config --encrypted rootpwd"
    assert_equal "$(mock_get_call_args "${slappasswd}" 1)" "-s configured-secret"
}
