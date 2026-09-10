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

@test "findBackendDatabaseDN should return nothing when ldapsearch fails" {
    # e.g. unreachable server or a missing search base - must not abort the caller.
    # Called through 'bash -c' on purpose: only there the 'set -o errexit' of the
    # sourced script is active, just like in startup.sh. A plain 'run <function>'
    # would silently disable it and pass even without the '|| true'.
    mock_set_status "${ldapsearch}" 1

    run bash -c "source /workspace/resources/rotate-root-password.sh; findBackendDatabaseDN"

    assert_success
    assert_output ""
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

@test "applyRootPassword should generate a random password when rootpwd is unset" {
    source /workspace/resources/rotate-root-password.sh

    mock_set_output "${ldapsearch}" "dn: ${backendDN}"
    
    # 1st call: 'doguctl config' fails because the key is unset
    mock_set_status "${doguctl}" 1 1
    
    # 2nd call: 'doguctl random' delivers the new password
    mock_set_output "${doguctl}" "random-secret" 2
    mock_set_status "${doguctl}" 0 2

    run applyRootPassword

    assert_success
    assert_line --partial "Rotating olcRootPW to replace a potentially insecure value"
    assert_line --partial "olcRootPW successfully set from generated source"

    assert_equal "$(mock_get_call_args "${doguctl}" 2)" "random"
    assert_equal "$(mock_get_call_args "${slappasswd}" 1)" "-s random-secret"
}

@test "applyRootPassword should write the hash to the backend DN and never the plaintext" {
    source /workspace/resources/rotate-root-password.sh

    mock_set_output "${ldapsearch}" "dn: ${backendDN}"
    mock_set_output "${doguctl}" "configured-secret"
    mock_set_output "${slappasswd}" "{SSHA}hashed-secret"
    # The script hands the LDIF (LDAP Data Interchange Format) to ldapmodify
    # on stdin (heredoc), and mock_get_call_args only records
    # arguments - never stdin. So make the mock write its own stdin to a file,
    # which we can then read back below.
    mock_set_side_effect "${ldapmodify}" "cat - > ${capturedLdif}"

    run applyRootPassword

    assert_success
    refute_output --partial "configured-secret"

    # Every 'run' overwrites $output, so from here on the assertions no longer
    # check the log of applyRootPassword but the LDIF captured above. It also
    # proves ldapmodify ran at all: without the call there is no file to cat.
    run cat "${capturedLdif}"
    assert_line "dn: ${backendDN}"
    assert_line "changetype: modify"
    assert_line "replace: olcRootPW"
    assert_line "olcRootPW: {SSHA}hashed-secret"
    refute_line --partial "configured-secret"
}

# A failed write must warn, not kill the dogu start. This is a deliberate
# trade-off: applyRootPassword runs in startup.sh between startInitDBDaemon and
# stopInitDBDaemon, before the service accounts are reconciled. Aborting there
# leaves a restart loop and unreconciled service accounts, so nobody can log in
# any more - not even the admin who would have to fix it. Continuing instead
# leaves a possibly weak password on an account that no dogu uses, and the next
# start retries the rotation anyway.
@test "applyRootPassword should not abort the startup when ldapmodify fails" {
    mock_set_output "${ldapsearch}" "dn: ${backendDN}"
    mock_set_output "${doguctl}" "configured-secret"
    mock_set_status "${ldapmodify}" 1

    # 'bash -c', so 'set -o errexit' really applies
    run bash -c "source /workspace/resources/rotate-root-password.sh; applyRootPassword"

    assert_success
    assert_line --partial "WARN: failed to write olcRootPW (configured) to ${backendDN}"
}
