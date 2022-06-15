FROM registry.cloudogu.com/official/base:3.14.3-1

LABEL NAME="official/ldap" \
      VERSION="2.4.58-3" \
      maintainer="hello@cloudogu.com"

ENV LDAP_VERSION="2.4.58-r0"

COPY ./resources /

# INSTALL SOFTWARE
RUN set -eux -o pipefail \
 && apk update \
 && apk upgrade \
 && apk add --update openldap=${LDAP_VERSION} openldap-clients openldap-back-hdb openldap-overlay-memberof openldap-overlay-refint openldap-overlay-unique openldap-overlay-ppolicy \
 && apk add mailx ssmtp su-exec \
 && rm -rf /var/cache/apk/* \
 # ensure permissions of scripts
 && chmod 755 startup.sh \
 && chmod 755 srv/openldap/create-sa.sh

# Set time zone to UTC so that time zone is the same as LDAP.
ENV TZ=UTC

# LDAP PORT
EXPOSE 389

# healtcheck
HEALTHCHECK CMD doguctl healthy ldap || exit 1

# FIRE IT UP
CMD ["/startup.sh"]
