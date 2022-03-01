FROM registry.cloudogu.com/official/base:3.11.6-2

LABEL NAME="official/ldap" \
      VERSION="2.4.48-3" \
      maintainer="christoph.wolfes@cloudogu.com"

ENV LDAP_VERSION="2.4.48-r3"

COPY ./resources /

# INSTALL SOFTWARE
RUN apk add --update openldap=${LDAP_VERSION} openldap-clients openldap-back-hdb openldap-overlay-memberof openldap-overlay-refint openldap-overlay-unique\
 && rm -rf /var/cache/apk/* \
 # ensure permissions of scripts
 && chmod 755 startup.sh \
 && chmod 755 srv/openldap/create-sa.sh

# VOLUMES
VOLUME ["/var/lib/ldap", "/etc/cesldap", "/etc/openldap"]

# LDAP PORT
EXPOSE 389

# healtcheck
HEALTHCHECK CMD doguctl healthy ldap || exit 1

# FIRE IT UP
CMD ["/startup.sh"]
