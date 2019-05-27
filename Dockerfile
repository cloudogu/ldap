FROM registry.cloudogu.com/official/base:3.9.4-1

MAINTAINER stephan christann <stephan.christann@christann.net>

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
