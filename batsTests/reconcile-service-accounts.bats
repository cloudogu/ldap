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
    ldapsearch="$(mock_create)"
    ldapadd="$(mock_create)"
    ldapmodify="$(mock_create)"
    ldapdelete="$(mock_create)"
    slappasswd="$(mock_create)"

    export PATH="${BATS_TMPDIR}:${PATH}"
    ln -s "${ldapsearch}" "${BATS_TMPDIR}/ldapsearch"
    ln -s "${ldapadd}" "${BATS_TMPDIR}/ldapadd"
    ln -s "${ldapmodify}" "${BATS_TMPDIR}/ldapmodify"
    ln -s "${ldapdelete}" "${BATS_TMPDIR}/ldapdelete"
    ln -s "${slappasswd}" "${BATS_TMPDIR}/slappasswd"
}

teardown() {
    rm "${BATS_TMPDIR}/ldapsearch"
    rm "${BATS_TMPDIR}/ldapadd"
    rm "${BATS_TMPDIR}/ldapmodify"
    rm "${BATS_TMPDIR}/ldapdelete"
    rm "${BATS_TMPDIR}/slappasswd"
}

@test "reconcile_account should create a new account if it does not exist" {
    source /workspace/resources/component/reconcile-service-accounts.sh

    # --- Arrange ---
    LDAP_DOMAIN="cloudogu.com"
    OPENLDAP_SUFFIX="dc=cloudogu,dc=com"
    LDAP_SA_MANAGED_TAG_PREFIX="ldap-managed"

    local account_id="cas"
    local access_type="rw"
    local enabled="true"
    local temp_dir="$(mktemp -d)"
    echo -n "cn=cas-sa,ou=Special Users,o=cloudogu.com,dc=cloudogu,dc=com" > "${temp_dir}/username"
    echo -n "password123" > "${temp_dir}/password"

    # Mock ldapsearch to return no results for this account_id (not managed yet)
    mock_set_status "${ldapsearch}" 0 # "0" but no output means not found in managed search
    mock_set_output "${ldapsearch}" "" 1

    # Mock ldapsearch for entry_exists (desired_dn)
    mock_set_status "${ldapsearch}" 1 2 # "1" indicates "not found"

    # Mock slappasswd
    mock_set_output "${slappasswd}" "{SSHA}encrypted-password" 1

    # Mock ldapadd to succeed
    mock_set_status "${ldapadd}" 0

    # --- Act ---
    run reconcile_account "${account_id}" "${access_type}" "${enabled}" "${temp_dir}"

    # --- Assert ---
    assert_success
    assert_line --partial "[SERVICE-ACCOUNT] creating 'cn=cas-sa,ou=Special Users,o=cloudogu.com,dc=cloudogu,dc=com'"
    
    # Verify that ldapadd was called to add the new user
    assert_equal "$(mock_get_call_num "${ldapadd}")" "1"
    assert_equal "$(mock_get_call_num "${ldapmodify}")" "1"

    rm -rf "${temp_dir}"
}

@test "reconcile_account should update an existing account if it already exists" {
    source /workspace/resources/component/reconcile-service-accounts.sh

    # --- Arrange ---
    LDAP_DOMAIN="cloudogu.com"
    OPENLDAP_SUFFIX="dc=cloudogu,dc=com"
    LDAP_SA_MANAGED_TAG_PREFIX="ldap-managed"

    local account_id="cas"
    local access_type="rw"
    local enabled="true"
    local temp_dir="$(mktemp -d)"
    echo -n "cn=cas-sa,ou=Special Users,o=cloudogu.com,dc=cloudogu,dc=com" > "${temp_dir}/username"
    echo -n "new-password" > "${temp_dir}/password"

    # Mock ldapsearch to return the same DN (managed account already exists)
    local existing_dn="cn=cas-sa,ou=Special Users,o=cloudogu.com,dc=cloudogu,dc=com"
    mock_set_status "${ldapsearch}" 0 1
    mock_set_output "${ldapsearch}" "dn: ${existing_dn}" 1

    # Mock ldapsearch for entry_exists (desired_dn)
    mock_set_status "${ldapsearch}" 0 2

    # Mock slappasswd
    mock_set_output "${slappasswd}" "{SSHA}new-encrypted-password" 1

    # Mock ldapmodify to succeed
    mock_set_status "${ldapmodify}" 0

    # --- Act ---
    run reconcile_account "${account_id}" "${access_type}" "${enabled}" "${temp_dir}"

    # --- Assert ---
    assert_success
    assert_line --partial "[SERVICE-ACCOUNT] updating '${existing_dn}'"
    
    # One modify for password/description, one modify to clear pwdReset.
    assert_equal "$(mock_get_call_num "${ldapmodify}")" "2"

    rm -rf "${temp_dir}"
}

@test "reconcile_account should remove account if disabled" {
    source /workspace/resources/component/reconcile-service-accounts.sh

    # --- Arrange ---
    LDAP_DOMAIN="cloudogu.com"
    OPENLDAP_SUFFIX="dc=cloudogu,dc=com"
    LDAP_SA_MANAGED_TAG_PREFIX="ldap-managed"

    local account_id="cas"
    local access_type="rw"
    local enabled="false"
    local temp_dir="$(mktemp -d)"

    # Mock ldapsearch to return an existing DN
    local existing_dn="cn=cas-sa,ou=Special Users,o=cloudogu.com,dc=cloudogu,dc=com"
    mock_set_status "${ldapsearch}" 0 1
    mock_set_output "${ldapsearch}" "dn: ${existing_dn}" 1

    # Mock entry_exists
    mock_set_status "${ldapsearch}" 0 2

    # Mock ldapdelete to succeed
    mock_set_status "${ldapdelete}" 0

    # --- Act ---
    run reconcile_account "${account_id}" "${access_type}" "${enabled}" "${temp_dir}"

    # --- Assert ---
    assert_success
    assert_line --partial "[SERVICE-ACCOUNT] 'cas' disabled; ensure account is removed."
    assert_line --partial "[SERVICE-ACCOUNT] removing '${existing_dn}'"
    
    # Verify that ldapdelete was called
    assert_equal "$(mock_get_call_num "${ldapdelete}")" "1"

    rm -rf "${temp_dir}"
}

@test "reconcile_account should remove account if credentials are missing" {
    source /workspace/resources/component/reconcile-service-accounts.sh

    # --- Arrange ---
    LDAP_DOMAIN="cloudogu.com"
    OPENLDAP_SUFFIX="dc=cloudogu,dc=com"
    LDAP_SA_MANAGED_TAG_PREFIX="ldap-managed"

    local account_id="cas"
    local access_type="rw"
    local enabled="true"
    local temp_dir="$(mktemp -d)" # Empty directory, no credentials

    # Mock ldapsearch to return an existing DN
    local existing_dn="cn=cas-sa,ou=Special Users,o=cloudogu.com,dc=cloudogu,dc=com"
    mock_set_status "${ldapsearch}" 0 1
    mock_set_output "${ldapsearch}" "dn: ${existing_dn}" 1

    # Mock entry_exists
    mock_set_status "${ldapsearch}" 0 2

    # Mock ldapdelete
    mock_set_status "${ldapdelete}" 0

    # --- Act ---
    run reconcile_account "${account_id}" "${access_type}" "${enabled}" "${temp_dir}"

    # --- Assert ---
    assert_success
    assert_line --partial "[SERVICE-ACCOUNT] 'cas' secret missing or incomplete; ensure account is removed."
    assert_line --partial "[SERVICE-ACCOUNT] removing '${existing_dn}'"
    
    assert_equal "$(mock_get_call_num "${ldapdelete}")" "1"

    rm -rf "${temp_dir}"
}

@test "reconcile_account should remove old DN if username changed" {
    source /workspace/resources/component/reconcile-service-accounts.sh

    # --- Arrange ---
    LDAP_DOMAIN="cloudogu.com"
    OPENLDAP_SUFFIX="dc=cloudogu,dc=com"
    LDAP_SA_MANAGED_TAG_PREFIX="ldap-managed"

    local account_id="cas"
    local access_type="rw"
    local enabled="true"
    local temp_dir="$(mktemp -d)"
    echo -n "cn=new-cas-sa,ou=Special Users,o=cloudogu.com,dc=cloudogu,dc=com" > "${temp_dir}/username"
    echo -n "password123" > "${temp_dir}/password"

    # Mock ldapsearch for managed_dns_for_account: returns an OLD DN
    local old_dn="cn=old-cas-sa,ou=Special Users,o=cloudogu.com,dc=cloudogu,dc=com"
    mock_set_status "${ldapsearch}" 0 1
    mock_set_output "${ldapsearch}" "dn: ${old_dn}" 1

    # Mock entry_exists for the old DN (inside delete_dn)
    mock_set_status "${ldapsearch}" 0 2

    # Mock entry_exists for the NEW DN (inside upsert_account) -> does not exist yet
    mock_set_status "${ldapsearch}" 1 3

    # Mock slappasswd
    mock_set_output "${slappasswd}" "{SSHA}encrypted" 1

    # Mock ldapdelete and ldapadd
    mock_set_status "${ldapdelete}" 0
    mock_set_status "${ldapadd}" 0

    # --- Act ---
    run reconcile_account "${account_id}" "${access_type}" "${enabled}" "${temp_dir}"

    # --- Assert ---
    assert_success
    assert_line --partial "[SERVICE-ACCOUNT] removing '${old_dn}'"
    assert_line --partial "[SERVICE-ACCOUNT] creating 'cn=new-cas-sa,ou=Special Users,o=cloudogu.com,dc=cloudogu,dc=com'"
    
    assert_equal "$(mock_get_call_num "${ldapdelete}")" "1"
    assert_equal "$(mock_get_call_num "${ldapadd}")" "1"
    assert_equal "$(mock_get_call_num "${ldapmodify}")" "1"

    rm -rf "${temp_dir}"
}

@test "reconcile_account should use 'Bind Users' OU for 'ro' access type" {
    source /workspace/resources/component/reconcile-service-accounts.sh

    # --- Arrange ---
    LDAP_DOMAIN="cloudogu.com"
    OPENLDAP_SUFFIX="dc=cloudogu,dc=com"
    LDAP_SA_MANAGED_TAG_PREFIX="ldap-managed"

    local account_id="ldap-mapper"
    local access_type="ro"
    local enabled="true"
    local temp_dir="$(mktemp -d)"
    echo -n "cn=mapper-sa,ou=Bind Users,o=cloudogu.com,dc=cloudogu,dc=com" > "${temp_dir}/username"
    echo -n "pwd" > "${temp_dir}/password"

    # Mock searches
    mock_set_status "${ldapsearch}" 0 1
    mock_set_output "${ldapsearch}" "" 1 # No managed yet
    mock_set_status "${ldapsearch}" 1 2 # Entry exists check

    # Mock slappasswd
    mock_set_output "${slappasswd}" "{SSHA}pwd" 1

    # Mock ldapadd
    mock_set_status "${ldapadd}" 0

    # --- Act ---
    run reconcile_account "${account_id}" "${access_type}" "${enabled}" "${temp_dir}"

    # --- Assert ---
    assert_success
    # Should use 'Bind Users' instead of 'Special Users'
    assert_line --partial "[SERVICE-ACCOUNT] creating 'cn=mapper-sa,ou=Bind Users,o=cloudogu.com,dc=cloudogu,dc=com'"
    assert_equal "$(mock_get_call_num "${ldapmodify}")" "1"
    
    rm -rf "${temp_dir}"
}

@test "reconcile_all_accounts should call reconcile_account for all dogus" {
    source /workspace/resources/component/reconcile-service-accounts.sh

    # Mock doguctl for reconcile_all_accounts
    doguctl="$(mock_create)"
    ln -s "${doguctl}" "${BATS_TMPDIR}/doguctl"
    
    # Mock calls inside reconcile_all_accounts
    # 1. LDAP_DOMAIN
    mock_set_output "${doguctl}" "cloudogu.com" 1
    # 2. OPENLDAP_SUFFIX
    mock_set_output "${doguctl}" "dc=cloudogu,dc=com" 2

    # Mock reconcile_account function to track calls
    # We redefine it to just echo its arguments
    reconcile_account() {
        echo "reconcile_account $1 $2 $3 $4"
    }

    # Set some dummy environment variables that the script would use
    export LDAP_SA_CAS_ENABLED="true"
    export LDAP_SA_USERMGT_ENABLED="false"
    export LDAP_SA_LDAP_MAPPER_ENABLED="true"

    run reconcile_all_accounts

    assert_success
    assert_line "reconcile_account cas rw true /etc/ces/service-accounts/cas"
    assert_line "reconcile_account usermgt rw false /etc/ces/service-accounts/usermgt"
    assert_line "reconcile_account ldap-mapper ro true /etc/ces/service-accounts/ldapMapper"

    rm "${BATS_TMPDIR}/doguctl"
}
