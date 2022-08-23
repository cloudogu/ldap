#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

export SLAPD_IPC_SOCKET=/run/openldap/ldapi

# escape url
# shellcheck disable=SC2001
_escurl() { echo "$1" | sed 's|/|%2F|g' ;}

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
    ldapadd -H "ldapi://$(_escurl ${SLAPD_IPC_SOCKET})" -f "${OPENLDAP_ETC_DIR}"/schema/ppolicy.ldif
  fi

  echo "add organizational unit (ou) for policies"
  ldapadd -H "ldapi://$(_escurl ${SLAPD_IPC_SOCKET})" <<EOF
dn: ou=Policies,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}
objectClass: organizationalUnit
objectClass: top
description: Root entry for policies
ou: Policies
EOF

  if [ "$existsPasswordPolicyConfiguration" != true ]; then
  echo "add password policy overlay"
  ldapadd -H "ldapi://$(_escurl ${SLAPD_IPC_SOCKET})" <<EOF
dn: olcOverlay=ppolicy,olcDatabase={1}hdb,cn=config
objectClass: olcOverlayConfig
objectClass: olcPPolicyConfig
olcOverlay: ppolicy
olcPPolicyDefault: cn=default,ou=Policies,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}
olcPPolicyHashCleartext: TRUE
EOF
  fi

  echo "add default password policy"
  ldapadd -H "ldapi://$(_escurl ${SLAPD_IPC_SOCKET})" <<EOF
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