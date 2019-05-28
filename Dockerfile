FROM registry.cloudogu.com/official/base:3.9.4-1

LABEL NAME="official/ldap" \
      VERSION="2.4.47-1" \
      maintainer="christoph.wolfes@cloudogu.com"


# INSTALL SOFTWARE
RUN apk add --update openldap openldap-clients openldap-back-hdb openldap-overlay-memberof openldap-overlay-refint \
 && rm -rf /var/cache/apk/*

# ADD resources
ADD resources /srv/openldap

# VOLUMES
VOLUME ["/var/lib/ldap", "/etc/cesldap"]

# LDAP PORT
EXPOSE 389

# FIRE IT UP
CMD ["/srv/openldap/startup.sh"]
