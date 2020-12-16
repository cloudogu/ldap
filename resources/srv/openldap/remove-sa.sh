#!/bin/bash -e

# variables which are used while rendering templates are exported

TYPE="$1"
SERVICE="$2"

if [ X"${SERVICE}" = X"" ]; then
    SERVICE="${TYPE}"
    TYPE=""
fi

if [ X"${SERVICE}" = X"" ]; then
    echo "usage remove-sa.sh servicename"
    exit 1
fi

OU="Bind Users"
if [ X"${TYPE}" = X"rw" ]; then
    OU="Special Users"
fi
export OU

LDAP_DOMAIN=$(doguctl config --global domain)
export LDAP_DOMAIN

OPENLDAP_SUFFIX=$(doguctl config openldap_suffix --default "dc=cloudogu,dc=com")

for result in $(ldapsearch -x -b "${OPENLDAP_SUFFIX}" "(cn=${SERVICE}*)" |grep -o "^cn:[ ]${SERVICE}[_].\{6\}$" |sed 's/cn:[ ]//g')
do
  export USERNAME="${result}"
  doguctl template /srv/openldap/remove-user.ldif.tpl /srv/openldap/remove-user_"${USERNAME}".ldif
  FILE="/srv/openldap/remove-user_${USERNAME}.ldif"
  echo "Removing ldap service account '${USERNAME}'"
  ldapmodify -f "${FILE}"
  echo "Removing temporary file '${FILE}'"
  rm "${FILE}"
done
