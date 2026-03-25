#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

service_account_ou() {
  case "$1" in
    rw) echo "Special Users" ;;
    ro) echo "Bind Users" ;;
    *)
      echo "unknown access type '$1' for service account reconciliation" >&2
      exit 1
      ;;
  esac
}

managed_dns_for_account() {
  local account_id="$1"
  local account_ou="$2"
  # `account_id` is the stable logical identifier (cas/usermgt/ldap-mapper), independent of username.
  # Managed entries are identified by a dedicated description marker per account id.
  ldapsearch -LLL -Q -Y EXTERNAL -H ldapi:/// \
    -b "ou=${account_ou},o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}" \
    "(description=${LDAP_SA_MANAGED_TAG_PREFIX}:${account_id})" dn 2>/dev/null \
    | sed -n 's/^dn: //p' || true
}

entry_exists() {
  local dn="$1"
  ldapsearch -LLL -Q -Y EXTERNAL -H ldapi:/// -b "${dn}" -s base dn >/dev/null 2>&1
}

# Service accounts are technical users and must be usable immediately after password
# create/update. With the active password policy, pwdReset=TRUE restricts the account
# to bind/unbind/password-change operations and blocks normal LDAP searches.
clear_pwd_reset() {
  local dn="$1"
  ldapmodify -Q -Y EXTERNAL -H ldapi:/// <<EOF
dn: ${dn}
changetype: modify
replace: pwdReset
pwdReset: FALSE
EOF
}

delete_dn() {
  local dn="$1"
  if entry_exists "${dn}"; then
    echo "[SERVICE-ACCOUNT] removing '${dn}'"
    ldapdelete -Q -Y EXTERNAL -H ldapi:/// "${dn}"
  fi
}

ensure_removed() {
  local account_id="$1"
  local account_ou="$2"
  local dn
  # `IFS=` here is scoped to the `read` builtin invocation and does not modify global IFS.
  while IFS= read -r dn; do
    [ -z "${dn}" ] && continue
    delete_dn "${dn}"
  done < <(managed_dns_for_account "${account_id}" "${account_ou}")
}

upsert_account() {
  local account_id="$1"
  local account_ou="$2"
  local desired_dn="$3"
  local password="$4"
  local service_account_cn
  local enc_password
  local dn

  # Extract the plain CN from the full bind DN for the LDAP entry payload,
  # e.g. `cn=cas-sa,ou=Special Users,o=cloudogu.com,dc=cloudogu,dc=com` -> `cas-sa`.
  service_account_cn="$(printf '%s' "${desired_dn}" | sed -n 's/^cn=\([^,]*\),.*$/\1/p')"
  if [[ -z "${service_account_cn}" ]]; then
    echo "invalid service account dn '${desired_dn}'" >&2
    exit 1
  fi

  enc_password="$(slappasswd -s "${password}")"

  # Keep exactly one managed DN per account id. If username changed, old DN is removed.
  # `IFS=` here is scoped to the `read` builtin invocation and does not modify global IFS.
  while IFS= read -r dn; do
    [ -z "${dn}" ] && continue
    if [[ "${dn}" != "${desired_dn}" ]]; then
      delete_dn "${dn}"
    fi
  done < <(managed_dns_for_account "${account_id}" "${account_ou}")

  if entry_exists "${desired_dn}"; then
    echo "[SERVICE-ACCOUNT] updating '${desired_dn}'"
    ldapmodify -Q -Y EXTERNAL -H ldapi:/// <<EOF
dn: ${desired_dn}
changetype: modify
replace: userPassword
userPassword: ${enc_password}
-
replace: description
description: ${LDAP_SA_MANAGED_TAG_PREFIX}:${account_id}
EOF
    clear_pwd_reset "${desired_dn}"
  else
    echo "[SERVICE-ACCOUNT] creating '${desired_dn}'"
    ldapadd -Q -Y EXTERNAL -H ldapi:/// <<EOF
dn: ${desired_dn}
cn: ${service_account_cn}
objectClass: organizationalRole
objectClass: simpleSecurityObject
description: ${LDAP_SA_MANAGED_TAG_PREFIX}:${account_id}
userPassword: ${enc_password}
EOF
    clear_pwd_reset "${desired_dn}"
  fi
}

reconcile_account() {
  local account_id="$1"
  local access_type="$2"
  local enabled="$3"
  local account_dir="$4"
  local account_ou
  local username=""
  local password=""

  # Reconcile algorithm:
  # 1) Resolve desired state from feature flag + secret files.
  # 2) If disabled or credentials missing: remove all LDAP entries for this account_id marker.
  # 3) If enabled + complete credentials: ensure exactly one DN with current credentials exists.
  account_ou="$(service_account_ou "${access_type}")"

  # Disabled account => enforce absence in LDAP.
  if [[ "${enabled}" != "true" ]]; then
    echo "[SERVICE-ACCOUNT] '${account_id}' disabled; ensure account is removed."
    ensure_removed "${account_id}" "${account_ou}"
    return
  fi

  # Secrets are mounted as files from Kubernetes Secret volumes.
  if [[ -f "${account_dir}/username" ]]; then
    username="$(tr -d '\r\n' < "${account_dir}/username")"
  fi
  if [[ -f "${account_dir}/password" ]]; then
    password="$(tr -d '\r\n' < "${account_dir}/password")"
  fi

  # Missing/empty credentials are treated as desired absence for deterministic reconcile.
  if [[ -z "${username}" || -z "${password}" ]]; then
    echo "[SERVICE-ACCOUNT] '${account_id}' secret missing or incomplete; ensure account is removed."
    ensure_removed "${account_id}" "${account_ou}"
    return
  fi

  upsert_account "${account_id}" "${account_ou}" "${username}" "${password}"
}

# --- Main logic ---
reconcile_all_accounts() {
  LDAP_DOMAIN="$(doguctl config --global domain)"
  OPENLDAP_SUFFIX="$(doguctl config openldap_suffix --default "dc=cloudogu,dc=com")"
  LDAP_SA_SECRET_BASE_DIR="${LDAP_SERVICE_ACCOUNT_SECRETS_DIR:-/etc/ces/service-accounts}"
  LDAP_SA_MANAGED_TAG_PREFIX="ldap-managed"

  reconcile_account "cas" "rw" "${LDAP_SA_CAS_ENABLED:-false}" "${LDAP_SA_SECRET_BASE_DIR}/cas"
  reconcile_account "usermgt" "rw" "${LDAP_SA_USERMGT_ENABLED:-false}" "${LDAP_SA_SECRET_BASE_DIR}/usermgt"
  reconcile_account "ldap-mapper" "ro" "${LDAP_SA_LDAP_MAPPER_ENABLED:-false}" "${LDAP_SA_SECRET_BASE_DIR}/ldapMapper"
}


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  reconcile_all_accounts
fi
