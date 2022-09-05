#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

function installPwdPolicy() {
  # set stage for health check
  doguctl state installing

  echo "add organizational unit (ou) for policies"
  _ldapadd <<EOF
dn: ou=Policies,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}
objectClass: organizationalUnit
objectClass: top
description: Root entry for policies
ou: Policies
EOF

  echo "add default password policy"
  _ldapadd <<EOF
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