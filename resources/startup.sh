#!/bin/bash
#shellcheck disable=SC2034  # variables are used for template rendering
set -o errexit
set -o nounset
set -o pipefail

# shellcheck disable=SC1091 # no direct access to the file
source /etc/ces/functions.sh

# based on https://github.com/dweomer/dockerfiles-openldap/blob/master/openldap.sh

LOGLEVEL=${LOGLEVEL:-0}

OPENLDAP_ETC_DIR="/etc/openldap"
OPENLDAP_RUN_DIR="/var/run/openldap"
OPENLDAP_RUN_ARGSFILE="${OPENLDAP_RUN_DIR}/slapd.args"
OPENLDAP_RUN_PIDFILE="${OPENLDAP_RUN_DIR}/slapd.pid"
OPENLDAP_MODULES_DIR="/usr/lib/openldap"
OPENLDAP_CONFIG_DIR="${OPENLDAP_ETC_DIR}/slapd.d"
OPENLDAP_BACKEND_DIR="/var/lib/openldap"
OPENLDAP_BACKEND_DATABASE="hdb"
OPENLDAP_BACKEND_OBJECTCLASS="olcHdbConfig"
OPENLDAP_ULIMIT="2048"
# proposal: use doguctl config openldap_suffix in future
OPENLDAP_SUFFIX="dc=cloudogu,dc=com"

ulimit -n ${OPENLDAP_ULIMIT}

# LDAP ALREADY INITIALIZED?
if [[ ! -d ${OPENLDAP_CONFIG_DIR}/cn=config ]]; then
  echo "initializing ldap"

  # set stage for health check
  doguctl state installing

  echo "removing old config files"
  # remove default configuration
  rm -f ${OPENLDAP_ETC_DIR}/*.conf

  echo "get domain and root password"
  # get domain and root password
  LDAP_ROOTPASS=$(doguctl random)
  doguctl config -e rootpwd "${LDAP_ROOTPASS}"
  LDAP_ROOTPASS_ENC=$(slappasswd -s "$LDAP_ROOTPASS")
  LDAP_BASE_DOMAIN=$(doguctl config --global domain)
  LDAP_DOMAIN=$(doguctl config --global domain)

  echo "get admin user details"
  CONFIG_USERNAME=$(doguctl config "admin_username")
  ADMIN_USERNAME=${CONFIG_USERNAME:-admin}

  ADMIN_MAIL=$(doguctl config "admin_mail") ||  ADMIN_MAIL="${ADMIN_USERNAME}@${DOMAIN}"

  CONFIG_GIVENNAME=$(doguctl config "admin_givenname") || CONFIG_GIVENNAME="admin"
  ADMIN_GIVENNAME=${CONFIG_GIVENNAME:-CES}

  CONFIG_SURNAME=$(doguctl config "admin_surname") || CONFIG_SURNAME="admin"
  ADMIN_SURNAME=${CONFIG_SURNAME:-Administrator}

  CONFIG_DISPLAYNAME=$(doguctl config "admin_displayname") || CONFIG_DISPLAYNAME="admin"
  ADMIN_DISPLAYNAME=${CONFIG_DISPLAYNAME:-CES Administrator}

  echo "get manager and admin group name"
  MANAGER_GROUP=$(doguctl config --global "manager_group") || MANAGER_GROUP="cesManager"
  ADMIN_GROUP=$(doguctl config --global admin_group) || ADMIN_GROUP="cesAdmin"
  ADMIN_MEMBER=$(doguctl config admin_member) || ADMIN_MEMBER="false"

  echo "get admin password"
  # TODO remove from etcd ???
  CONFIG_PASSWORD=$(doguctl config -e "admin_password")
  ADMIN_PASSWORD=${CONFIG_PASSWORD:-admin}
  ADMIN_PASSWORD_ENC="$(slappasswd -s "$ADMIN_PASSWORD")"

  mkdir -p ${OPENLDAP_CONFIG_DIR}

  if [[ ! -s ${OPENLDAP_ETC_DIR}/ldap.conf ]]; then
    echo "rendering ldap.conf template"
    doguctl template /srv/openldap/conf.d/ldap.conf.tpl ${OPENLDAP_ETC_DIR}/ldap.conf
  fi

  if [[ ! -s ${OPENLDAP_ETC_DIR}/slapd-config.ldif ]]; then
    echo "rendering slapd-config.ldif template"
    render_template /srv/openldap/conf.d/slapd-config.ldif.tpl > ${OPENLDAP_ETC_DIR}/slapd-config.ldif
  fi

  slapadd -n0 -F ${OPENLDAP_CONFIG_DIR} -l ${OPENLDAP_ETC_DIR}/slapd-config.ldif > ${OPENLDAP_ETC_DIR}/slapd-config.ldif.log

  mkdir -p ${OPENLDAP_BACKEND_DIR}/run
  chown -R ldap:ldap ${OPENLDAP_BACKEND_DIR}
  chown -R ldap:ldap ${OPENLDAP_CONFIG_DIR} ${OPENLDAP_BACKEND_DIR}
  mkdir -p ${OPENLDAP_RUN_DIR}
  chown -R ldap:ldap ${OPENLDAP_RUN_DIR}

  if [[ -d /srv/openldap/ldif.d ]]; then

    while IFS= read -r -d '' f
    do
      render_template "${f//.tpl/}"
    done < <(find /srv/openldap/ldif.d -type f -name "*.tpl" | sort)

    slapd_exe=$(command -v slapd)
    echo >&2 "$0 ($slapd_exe): starting initdb daemon"
    slapd -u ldap -g ldap -h ldapi:///

    while IFS= read -r -d '' f
    do
       echo >&2 "applying $f"
      ldapadd -Y EXTERNAL -f "$f" 2>&1
    done < <(find /srv/openldap/ldif.d -type f -name "*.ldif" | sort)

    # if ADMIN_MEMBER is true add admin to member group for tool admin rights
    if [[ ${ADMIN_MEMBER} = "true" ]]; then
      ldapmodify -Y EXTERNAL << EOF
dn: cn=${ADMIN_GROUP},ou=Groups,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}
changetype: modify
replace: member
member: uid=${ADMIN_USERNAME},ou=People,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}
member: cn=__dummy
EOF
    fi
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
  fi
fi

# set stage for health check
doguctl state ready

/usr/sbin/slapd -h "ldapi:/// ldap:///" -u ldap -g ldap -d "$LOGLEVEL"
