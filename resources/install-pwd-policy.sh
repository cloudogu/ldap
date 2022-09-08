#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

function installPwdPolicyIfNecessary() {

  if ! ldapsearch -b "cn=module{0},cn=config" 2>/dev/null | grep ppolicy >/dev/null; then
    echo "[PWD-POLICY-INSTALL] install password policy module"
    ldapadd <<EOF
dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: ppolicy
EOF
  fi

  policyDN="ou=Policies,o=$LDAP_DOMAIN,$OPENLDAP_SUFFIX"
  if ! ldapsearch -b "$policyDN" >/dev/null; then
    echo "[PWD-POLICY-INSTALL] add organizational unit (ou) for policies"
    ldapadd <<EOF
dn: ou=Policies,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}
objectClass: organizationalUnit
objectClass: top
description: Root entry for policies
ou: Policies
EOF
  fi

  if ! ldapsearch -b olcDatabase={1}mdb,cn=config 2>/dev/null | grep -i overlay | grep ppolicy >/dev/null; then
    echo "[PWD-POLICY-INSTALL] add password policy overlay"
    ldapadd <<EOF
dn: olcOverlay=ppolicy,olcDatabase={1}mdb,cn=config
objectClass: olcOverlayConfig
objectClass: olcPPolicyConfig
olcOverlay: ppolicy
olcPPolicyDefault: cn=default,ou=Policies,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}
olcPPolicyHashCleartext: TRUE
EOF
  fi

  if ! ldapsearch -b "cn=default,ou=Policies,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}" >/dev/null; then
    echo "[PWD-POLICY-INSTALL] add default password policy"
    ldapadd <<EOF
dn: cn=default,ou=Policies,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}
objectClass: person
objectClass: pwdPolicy
cn: default
sn: pwpolicy
pwdAttribute: userPassword
pwdMustChange: TRUE
EOF
  fi
}
