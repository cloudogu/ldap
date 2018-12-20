FROM registry.cloudogu.com/official/base:3.5-5

MAINTAINER stephan christann <stephan.christann@christann.net>

# INSTALL SOFTWARE
RUN apk add --update openldap openldap-clients openldap-back-hdb \
 && rm -rf /var/cache/apk/*

# ADD resources
ADD resources /

# VOLUMES
VOLUME ["/var/lib/ldap", "/etc/cesldap"]

# LDAP PORT
EXPOSE 389

# FIRE IT UP
CMD ["/startup.sh"]
