#!/bin/sh
set -eu

# Prepare persistent directories used by slapd data/config and local CES config.
mkdir -p /persistence/db /persistence/config /persistence/local-config
# Prefer ldap ownership; if CHOWN is not allowed, fall back to permissive mode.
if ! chown -R 100:101 /persistence/db /persistence/config /persistence/local-config 2>/dev/null; then
  chmod -R 0777 /persistence/db /persistence/config /persistence/local-config || true
fi

# Copy immutable OpenLDAP files from the image into a writable runtime volume.
cp -a /etc/openldap/. /openldap-etc/
chmod -R 0777 /openldap-etc

# Extract the dogu version to mimic the expected /etc/ces/dogu_json layout.
DOGU_VERSION="$(sed -n 's/.*\"Version\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p' /dogu.json | head -n1)"
if [ -z "${DOGU_VERSION}" ]; then
  echo "unable to determine dogu version from /dogu.json" >&2
  exit 1
fi

# Create host-scoped dogu_json metadata expected by doguctl in multinode mode.
HOST_DOGU_DIR="/ces-dogu-json/${HOSTNAME}"
mkdir -p "${HOST_DOGU_DIR}"
printf '%s' "${DOGU_VERSION}" > "${HOST_DOGU_DIR}/current"
cp /dogu.json "${HOST_DOGU_DIR}/${DOGU_VERSION}"
chown -R 100:101 /ces-dogu-json 2>/dev/null || true
