#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

function installPwdPolicy() {
  # set stage for health check
  doguctl state installing

  existsPasswordPolicyConfiguration=false
  PASSWORD_SCHEMA_FILE="${OPENLDAP_CONFIG_DIR}/cn=config/cn=schema/cn={4}ppolicy.ldif"
  if [ -f "$PASSWORD_SCHEMA_FILE" ]; then
    echo "configuration of password policy already exists; only add LDAP entries."
    existsPasswordPolicyConfiguration=true
  fi

  if [ "$existsPasswordPolicyConfiguration" != true ]; then
    # start installation and configuration of password policy
    echo "include password policy schema"
    ldapadd -Y EXTERNAL -H ldapi:/// -f "${OPENLDAP_ETC_DIR}"/schema/ppolicy.ldif
  fi

  if [ "$existsPasswordPolicyConfiguration" != true ]; then
    echo "install password policy module"
    ldapadd -Y EXTERNAL -H ldapi:/// <<EOF
dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: ppolicy
EOF
  fi

  echo "add organizational unit (ou) for policies"
  ldapadd -Y EXTERNAL -H ldapi:/// <<EOF
dn: ou=Policies,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}
objectClass: organizationalUnit
objectClass: top
description: Root entry for policies
ou: Policies
EOF

  if [ "$existsPasswordPolicyConfiguration" != true ]; then
  echo "add password policy overlay"
  ldapadd -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcOverlay=ppolicy,olcDatabase={1}hdb,cn=config
objectClass: olcOverlayConfig
objectClass: olcPPolicyConfig
olcOverlay: ppolicy
olcPPolicyDefault: cn=default,ou=Policies,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}
olcPPolicyHashCleartext: TRUE
EOF
  fi

  echo "add default password policy"
  ldapadd -Y EXTERNAL -H ldapi:/// <<EOF
dn: cn=default,ou=Policies,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}
objectClass: person
objectClass: pwdPolicy
cn: default
sn: pwpolicy
pwdAttribute: userPassword
pwdMustChange: TRUE
EOF

  echo "Installation and configuration of password policy finished"
}