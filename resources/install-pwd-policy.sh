#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

function installPwdPolicy() {
  # set stage for health check
  doguctl state installing

  # start slapd; since LDAP has not yet been started, slapd must be started explicitly in order to make changes
  # and additions.
  slapd_exe=$(command -v slapd)
  echo >&2 "$0 ($slapd_exe): starting initdb daemon"
  slapd -u ldap -g ldap -h ldapi:///

  # start installation and configuration of password policy
  echo "include password policy schema"
  ldapadd -Y EXTERNAL -H ldapi:/// -f ${OPENLDAP_ETC_DIR}/schema/ppolicy.ldif

  echo "install password policy module"
  ldapadd -Y EXTERNAL -H ldapi:/// <<EOF
dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: ppolicy
EOF

  echo "add organizational unit (ou) for policies"
  ldapadd -Y EXTERNAL -H ldapi:/// <<EOF
dn: ou=Policies,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}
objectClass: organizationalUnit
objectClass: top
ou: Policies
EOF

  echo "add password policy overlay"
  ldapadd -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcOverlay=ppolicy,olcDatabase={1}hdb,cn=config
objectClass: olcOverlayConfig
objectClass: olcPPolicyConfig
olcOverlay: ppolicy
olcPPolicyDefault: cn=default,ou=Policies,dc=cloudogu,dc=com
olcPPolicyHashCleartext: TRUE
EOF

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

  echo "Installation and configuriation of password policy finished"

  # stop slapd again
  if [[ ! -s ${OPENLDAP_RUN_PIDFILE} ]]; then
    echo >&2 "$0 ($slapd_exe): ${OPENLDAP_RUN_PIDFILE} is missing, did the daemon start?"
    exit 1
  else
    slapd_pid=$(cat ${OPENLDAP_RUN_PIDFILE})
    echo >&2 "$0 ($slapd_exe): sending SIGINT to initdb daemon with pid=$slapd_pid"
    kill -s INT "$slapd_pid" || true
    while : ; do
      [[ ! -f ${OPENLDAP_RUN_PIDFILE} ]] && break
      sleep 1
      echo >&2 "$0 ($slapd_exe): initdb daemon is still up, sleeping ..."
    done
    echo >&2 "$0 ($slapd_exe): initdb daemon stopped"
  fi
}