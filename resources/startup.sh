#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

echo "                                     ./////,                    "
echo "                                 ./////==//////*                "
echo "                                ////.  ___   ////.              "
echo "                         ,**,. ////  ,////A,  */// ,**,.        "
echo "                    ,/////////////*  */////*  *////////////A    "
echo "                   ////'        \VA.   '|'   .///'       '///*  "
echo "                  *///  .*///*,         |         .*//*,   ///* "
echo "                  (///  (//////)**--_./////_----*//////)   ///) "
echo "                   V///   '°°°°      (/////)      °°°°'   ////  "
echo "                    V/////(////////\. '°°°' ./////////(///(/'   "
echo "                       'V/(/////////////////////////////V'      "

# based on https://github.com/dweomer/dockerfiles-openldap/blob/master/openldap.sh

# shellcheck disable=SC1091
source install-pwd-policy.sh

# shellcheck disable=SC1091
source /scheduled_jobs.sh

LOGLEVEL=${LOGLEVEL:-0}

# variables which are used while rendering templates are exported
export OPENLDAP_ETC_DIR="/etc/openldap"
OPENLDAP_RUN_DIR="/var/run/openldap"
OPENLDAP_SOCKET_DIR="/var/lib/openldap/run"
export OPENLDAP_RUN_ARGSFILE="${OPENLDAP_RUN_DIR}/slapd.args"
export OPENLDAP_RUN_PIDFILE="${OPENLDAP_RUN_DIR}/slapd.pid"
export OPENLDAP_MODULES_DIR="/usr/lib/openldap"
export OPENLDAP_CONFIG_DIR="${OPENLDAP_ETC_DIR}/slapd.d"
export OPENLDAP_BACKEND_DIR="/var/lib/openldap"
export OPENLDAP_BACKEND_DATABASE="mdb"
export OPENLDAP_BACKEND_OBJECTCLASS="olcMdbConfig"
OPENLDAP_ULIMIT="2048"

# proposal: use doguctl config openldap_suffix in future
export OPENLDAP_SUFFIX="dc=cloudogu,dc=com"

# migration tmp folder
export MIGRATION_TMP_DIR="/tmp/migration"
ulimit -n ${OPENLDAP_ULIMIT}

function waitForLdapHealth {
  while true; do
    echo "Waiting for ldap health..."
    local EXIT_CODE
    EXIT_CODE="$(
      ldapsearch >/dev/null 2>&1
      echo $?
    )"
    if [[ "${EXIT_CODE}" == 32 ]]; then
      break
    fi
    sleep 1
  done
  echo "Ldap is healthy..."
}

function startInitDBDaemon {
  slapd_exe=$(command -v slapd)
  echo >&2 "$0 ($slapd_exe): starting initdb daemon"

  # create openldap dir
  if [[ ! -d ${OPENLDAP_SOCKET_DIR} ]]; then
    echo "Creating ldap socket dir"
    mkdir -p ${OPENLDAP_SOCKET_DIR}
  fi
  chown -R ldap:ldap ${OPENLDAP_SOCKET_DIR}

  /usr/sbin/slapd -h ldapi:/// -u ldap -g ldap
  waitForLdapHealth
}

function stopInitDBDaemon {
  if [[ ! -s ${OPENLDAP_RUN_PIDFILE} ]]; then
    echo >&2 "$0 ($slapd_exe): ${OPENLDAP_RUN_PIDFILE} is missing, did the daemon start?"
    exit 1
  else
    slapd_pid=$(cat ${OPENLDAP_RUN_PIDFILE})
    echo >&2 "$0 ($slapd_exe): sending SIGINT to initdb daemon with pid=$slapd_pid"
    kill -s INT "$slapd_pid" || true
    while :; do
      [[ ! -f ${OPENLDAP_RUN_PIDFILE} ]] && break
      sleep 1
      echo >&2 "$0 ($slapd_exe): initdb daemon is still up, sleeping ..."
    done
    echo >&2 "$0 ($slapd_exe): initdb daemon stopped"
  fi
}

# create openldap dir
if [[ ! -d ${OPENLDAP_RUN_DIR} ]]; then
  mkdir -p ${OPENLDAP_RUN_DIR}
fi
chown -R ldap:ldap ${OPENLDAP_RUN_DIR}

# Generate ldap.conf and slapd-config.ldif.
# This has to be done at every dogu start. Otherwise service account operations will fail
# because ldapadd uses the default configuration which are not compatible with the backend
echo "[DOGU] Removing old config files ..."

# remove default configuration
rm -f ${OPENLDAP_ETC_DIR}/*.conf

# get domain and root password
echo "[DOGU] Get domain and root password ..."
LDAP_ROOTPASS=$(doguctl random)
LDAP_CONFIG_PASS=$(doguctl config -e -d "${LDAP_ROOTPASS}" rootpwd)
LDAP_ROOTPASS_ENC=$(slappasswd -s "${LDAP_CONFIG_PASS}")
export LDAP_ROOTPASS_ENC

LDAP_DOMAIN=$(doguctl config --global domain)
export LDAP_DOMAIN

if [[ ! -s ${OPENLDAP_ETC_DIR}/ldap.conf ]]; then
  echo "[DOGU] Rendering ldap.conf template ..."
  doguctl template /srv/openldap/conf.d/ldap.conf.tpl ${OPENLDAP_ETC_DIR}/ldap.conf
fi

if [[ ! -s ${OPENLDAP_ETC_DIR}/slapd-config.ldif ]]; then
  echo "[DOGU] Rendering slapd-config.ldif template ..."
  doguctl template /srv/openldap/conf.d/slapd-config.ldif.tpl ${OPENLDAP_ETC_DIR}/slapd-config.ldif
fi

# For Migration only 2.4.X -> 2.6.X. Cloud be removed in further upgrades!
MIGRATION_IN_PROGRESS="$(doguctl config --default "false" migration_mdb_hdb)"
while [[ "${MIGRATION_IN_PROGRESS}" == "true" ]]; do
  echo "Migration from mdb to hdb in progress..."
  sleep 1
  MIGRATION_IN_PROGRESS="$(doguctl config --default "false" migration_mdb_hdb)"
done

# LDAP ALREADY INITIALIZED?
if [[ ! -d ${OPENLDAP_CONFIG_DIR}/cn=config ]]; then
  echo "[DOGU] Initializing ldap ..."

  # set stage for health check
  doguctl state installing

  echo "[DOGU] Get admin user details ..."
  ADMIN_USERNAME=$(doguctl config -d admin admin_username)
  export ADMIN_USERNAME

  echo "[DOGU] Get manager and admin group name ..."
  MANAGER_GROUP=$(doguctl config --global -d cesManager manager_group)
  export MANAGER_GROUP

  ADMIN_GROUP=$(doguctl config --global -d cesAdmin admin_group)
  export ADMIN_GROUP

  ADMIN_MEMBER=$(doguctl config -d false admin_member)

  ADMIN_GIVENNAME=$(doguctl config -d admin admin_givenname)
  export ADMIN_GIVENNAME

  ADMIN_SURNAME=$(doguctl config -d admin admin_surname)
  export ADMIN_SURNAME

  ADMIN_DISPLAYNAME=$(doguctl config -d admin admin_displayname)
  export ADMIN_DISPLAYNAME

  DEFAULT_ADMIN_MAIL="${ADMIN_USERNAME}@${LDAP_DOMAIN}"
  ADMIN_MAIL=$(doguctl config -d "${DEFAULT_ADMIN_MAIL}" admin_mail)
  export ADMIN_MAIL

  echo "[DOGU] Get admin password ..."
  # TODO remove from etcd ???
  ADMIN_PASSWORD=$(doguctl config -e -d admin admin_password)
  ADMIN_PASSWORD_ENC="$(slappasswd -s "${ADMIN_PASSWORD}")"
  export ADMIN_PASSWORD_ENC

  mkdir -p ${OPENLDAP_CONFIG_DIR}

  slapadd -n0 -F ${OPENLDAP_CONFIG_DIR} -l ${OPENLDAP_ETC_DIR}/slapd-config.ldif >${OPENLDAP_ETC_DIR}/slapd-config.ldif.log
  # has to be called after slapadd because slapadd generates the files in ${OPENLDAP_CONFIG_DIR}
  chown -R ldap:ldap ${OPENLDAP_CONFIG_DIR}

  mkdir -p ${OPENLDAP_BACKEND_DIR}/run

  shopt -s globstar nullglob
  for file in /srv/openldap/ldif.d/*.tpl; do
    # render template for all .tpl files and create files without .tpl ending
    doguctl template "$file" "${file//".tpl"/""}"
  done
  shopt -u globstar nullglob

  startInitDBDaemon

  rootDN="o=$LDAP_DOMAIN,$OPENLDAP_SUFFIX"
  if ! ldapsearch -b "$rootDN" >/dev/null; then
    for f in $(find /srv/openldap/ldif.d -type f -name "*.ldif" | sort); do
      echo >&2 "applying $f"
      ldapadd -f "$f" 2>&1
    done
  else
    echo "Root entry already exists; continue"
  fi

  # if ADMIN_MEMBER is true add admin to member group for tool admin rights
  if [[ ${ADMIN_MEMBER} = "true" ]]; then
    ldapmodify <<EOF
dn: cn=${ADMIN_GROUP},ou=Groups,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}
changetype: modify
replace: member
member: uid=${ADMIN_USERNAME},ou=People,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}
member: cn=__dummy
EOF
  fi

  stopInitDBDaemon
fi

# does password entry already exists?
startInitDBDaemon

installPwdPolicyIfNecessary

stopInitDBDaemon

echo "[DOGU] Update password change notification user ..."
update_pwd_change_notification_user

echo "[DOGU] Setup cron job ..."
setup_cron

echo "[DOGU] Update password change sender address mapping ..."
update_email_sender_alias_mapping

# set stage for health check
doguctl state ready

echo "Starting ldap..."
/usr/sbin/slapd -h "ldapi:/// ldap:///" -u ldap -g ldap -d "${LOGLEVEL}"
