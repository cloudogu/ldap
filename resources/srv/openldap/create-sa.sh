#!/bin/bash -e

# variables which are used while rendering templates are exported

{
    TYPE="$1"
    SERVICE="$2"

    if [ X"${SERVICE}" = X"" ]; then
        SERVICE="${TYPE}"
        TYPE=""
    fi
    
    if [ X"${SERVICE}" = X"" ]; then
        echo "usage create-sa.sh servicename"
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
    export OPENLDAP_SUFFIX

    # create random schema suffix and password
    USERNAME="${SERVICE}_$(doguctl random -l 6)"
    export USERNAME
    PASSWORD=$(doguctl random)
    ENC_PASSWORD=$(slappasswd -s "${PASSWORD}")
    export ENC_PASSWORD
    doguctl template /srv/openldap/new-user.ldif.tpl /srv/openldap/new-user_"${USERNAME}".ldif
    ldapadd -f "/srv/openldap/new-user_${USERNAME}.ldif"

} >/dev/null 2>&1

# print details
echo "username: cn=${USERNAME},ou=${OU},o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}"
echo "password: ${PASSWORD}"
