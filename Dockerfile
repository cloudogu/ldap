ARG DOGU_BASE_IMAGE=registry.cloudogu.com/official/base:3.23.3-4
ARG ALPINE_BASE_IMAGE=alpine:3.23
ARG OPENLDAP_PKG_VER=2.6.10-r0

FROM scratch AS ldap-resources
COPY ./resources /
COPY ./dogu.json /dogu.json

FROM ${DOGU_BASE_IMAGE} AS dogu-base

FROM ${ALPINE_BASE_IMAGE} AS ldap-common
ARG OPENLDAP_PKG_VER

RUN set -eux -o pipefail \
    && apk update \
    && apk upgrade \
    && apk add --update openldap=${OPENLDAP_PKG_VER} openldap-clients openldap-back-mdb \
                     openldap-overlay-memberof openldap-overlay-refint openldap-overlay-unique \
                     openldap-overlay-ppolicy \
                     openldap-overlay-sssvlv \
                     ca-certificates jq openssl tar zip unzip mailx ssmtp \
                     bash \
                     su-exec \
    && rm -rf /var/cache/apk/*

ENV TZ=UTC
EXPOSE 389

COPY --from=ldap-resources / /
COPY --from=dogu-base /usr/local/bin/doguctl /usr/local/bin/doguctl
RUN chmod 755 /startup.sh /usr/local/bin/doguctl

FROM ldap-common AS component

LABEL NAME="k8s/ldap" \
      VERSION="2.6.8-7" \
      maintainer="hello@cloudogu.com"
HEALTHCHECK CMD ldapsearch -x -H ldap://127.0.0.1:389 -b "" -s base >/dev/null 2>&1 || exit 1
CMD ["/startup.sh"]

FROM ldap-common AS dogu

LABEL NAME="official/ldap" \
      VERSION="2.6.8-7" \
      maintainer="hello@cloudogu.com"

RUN set -eux -o pipefail \
    && chmod 755 /srv/openldap/create-sa.sh

HEALTHCHECK CMD doguctl healthy ldap || exit 1
CMD ["/startup.sh"]
