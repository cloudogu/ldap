#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

function installPwdPolicyIfNecessary() {
  policyDN="ou=Policies,o=$LDAP_DOMAIN,$OPENLDAP_SUFFIX"
  if ! ldapsearch -b "$policyDN" >/dev/null; then
    # set stage for health check
    doguctl state installing
    echo "installing password policy..."
    echo "add organizational unit (ou) for policies"
    ldapadd <<EOF
dn: ou=Policies,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}
objectClass: organizationalUnit
objectClass: top
description: Root entry for policies
ou: Policies
EOF

    echo "add default password policy"
    ldapadd <<EOF
dn: cn=default,ou=Policies,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}
objectClass: person
objectClass: pwdPolicy
cn: default
sn: pwpolicy
pwdAttribute: userPassword
pwdMustChange: TRUE
EOF
    echo "Installation and configuration of password policy finished"
  else
    echo "password policy is already installed; nothing to do here"
  fi

  if ! ldapsearch -b "cn=module{0},cn=config" 2>/dev/null | grep ppolicy >/dev/null; then
    # set stage for health check
    doguctl state installing
    echo "including password policy module"
    ldapadd <<EOF
dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: ppolicy
EOF
  echo "included password policy module"
  else
    echo "password policy module is already included; nothing to do here"
  fi

}
