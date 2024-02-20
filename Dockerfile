FROM registry.cloudogu.com/official/base:3.15.8-1

LABEL NAME="official/ldap" \
      VERSION="2.6.2-6" \
      maintainer="hello@cloudogu.com"

ENV LDAP_VERSION="2.6.2-r0"

COPY ./resources /

# Install application and dependencies
RUN set -eux -o pipefail \
    && apk add --update openldap=${LDAP_VERSION} openldap-clients openldap-back-mdb \
                     openldap-overlay-memberof openldap-overlay-refint openldap-overlay-unique \
                     openldap-overlay-ppolicy  \
                     openldap-overlay-sssvlv \
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
