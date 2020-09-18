FROM registry.cloudogu.com/official/base:3.9.4-1

LABEL NAME="official/ldap" \
      VERSION="2.4.47-1" \
      maintainer="christoph.wolfes@cloudogu.com"

COPY ./resources /

# INSTALL SOFTWARE
RUN apk add --update openldap nano openldap-clients openldap-back-hdb openldap-overlay-memberof openldap-overlay-refint openldap-overlay-unique\
 && rm -rf /var/cache/apk/* \
 # ensure permissions of scripts
 && chmod 755 startup.sh \
 && chmod 755 srv/openldap/create-sa.sh

# VOLUMES
VOLUME ["/var/lib/ldap", "/etc/cesldap"]

# LDAP PORT
EXPOSE 389

# FIRE IT UP
CMD ["/startup.sh"]
