#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

# Prepare persistent directories used by slapd data/config and local CES config.
init_persistence_layout() {
  mkdir -p /persistence/db /persistence/config /persistence/local-config
  # Prefer ldap ownership; if CHOWN is not allowed, log it and use group-writable fallback.
  if ! chown -R 100:101 /persistence/db /persistence/config /persistence/local-config 2>/dev/null; then
    echo "WARN: chown for persistence dirs failed; falling back to u+rwX,g+rwX permissions." >&2
    chmod -R u+rwX,g+rwX,o-rwx /persistence/db /persistence/config /persistence/local-config || true
  fi

  # Copy immutable OpenLDAP base files (e.g. ldap.conf + schema defaults from the image)
  # into the shared volume mounted at /openldap-etc (init) and later at /etc/openldap (main container).
  cp -a /etc/openldap/. /openldap-etc/
  chmod -R 0777 /openldap-etc

  # Extract the dogu version to mimic the expected /etc/ces/dogu_json layout.
  DOGU_VERSION="$(sed -n 's/.*\"Version\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p' /dogu.json | head -n1)"
  if [ -z "${DOGU_VERSION}" ]; then
    echo "unable to determine dogu version from /dogu.json" >&2
    exit 1
  fi

  # Create host-scoped dogu_json metadata in its dedicated shared volume.
  # This is intentionally independent from the openldap-etc volume.
  HOST_DOGU_DIR="/ces-dogu-json/${HOSTNAME}"
  mkdir -p "${HOST_DOGU_DIR}"
  printf '%s' "${DOGU_VERSION}" > "${HOST_DOGU_DIR}/current"
  cp /dogu.json "${HOST_DOGU_DIR}/${DOGU_VERSION}"
  if ! chown -R 100:101 /ces-dogu-json 2>/dev/null; then
    echo "WARN: chown for /ces-dogu-json failed; continuing because files are read-only metadata for the runtime container." >&2
  fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  init_persistence_layout
fi
