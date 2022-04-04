#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

function installPwdPolicy() {
 ## Quelle: https://kifarunix.com/implement-openldap-password-policies/

  OPENLDAP_RUN_DIR="/var/run/openldap"
  export OPENLDAP_RUN_ARGSFILE="${OPENLDAP_RUN_DIR}/slapd.args"
  export OPENLDAP_RUN_PIDFILE="${OPENLDAP_RUN_DIR}/slapd.pid"

  # set stage for health check
  doguctl state installing

  slapd_exe=$(command -v slapd)
  echo >&2 "$0 ($slapd_exe): starting initdb daemon"

  slapd -u ldap -g ldap -h ldapi:///

  echo "Install password policy module"
  ldapadd -Y EXTERNAL -H ldapi:/// <<EOF
dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: ppolicy
EOF

  echo "Add policies OU hinzufügen"
  ldapadd -Y EXTERNAL -H ldapi:/// <<EOF
dn: ou=Policies,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}
objectClass: organizationalUnit
objectClass: top
ou: Policies
EOF

  echo "Include password policy schema"
  # 3) PW-Schema inkludieren (muss im Schema-Ordner () ausgeführt werden
  ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/schema/ppolicy.ldif

  echo "Add password policy overlay"
  ## 4) Password-Policy-Overlay hinzufügen
  ldapadd -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcOverlay=ppolicy,olcDatabase={1}hdb,cn=config
objectClass: olcOverlayConfig
objectClass: olcPPolicyConfig
olcOverlay: ppolicy
olcPPolicyDefault: cn=default,ou=Policies,dc=cloudogu,dc=com
olcPPolicyHashCleartext: TRUE
EOF

  echo "Add default password policy"
  ## 5) Eine konkrete Password-Policy hinzufügen
  ldapadd -Y EXTERNAL -H ldapi:/// <<EOF
dn: cn=default,ou=Policies,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}
objectClass: person
objectClass: pwdPolicy
cn: pwpolicy
sn: pwpolicy
pwdAttribute: userPassword
pwdMustChange: TRUE
EOF

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