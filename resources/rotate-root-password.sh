#!/bin/bash
# Sets the backend root password (olcRootPW) on every dogu start.
#
# It used to be written only once during the very first start. olcRootPW
# belongs to olcRootDN (cn=admin). So on instances first installed with a base
# image shipping doguctl < 0.12.2 still hold a `math/rand` (unsecure) value.
# Service accounts and the CES admin user are not touched.
# olc => open ldap configuration
set -o errexit
set -o nounset
set -o pipefail

# Prints the plain DN values of an LDIF block, one per line
# "dn: olcDatabase={1}mdb,cn=config"  ->  "olcDatabase={1}mdb,cn=config"
function extractDNs() {
  local ldifBlock="$1"

  # ^       - anchor to the line start
  # "^dn: " - filter lines including "dn: " in the beginning of the line
  # --quiet - suppress automatic printing of pattern space
  # p       - print only lines with the given filter "dn: "
  # <<<     - feed the string as stdin
  sed --quiet 's/^dn: //p' <<< "${ldifBlock}"
}

# Prints the DN of the backend database
function findBackendDatabaseDN() {

  local connectTo="ldapi:///"
  local searchBase="cn=config"
  local searchFilter="(olcSuffix=${OPENLDAP_SUFFIX})"
  local wantedAttribute="dn"
  local searchResult

  # Search in ldap
  # -Q    - SASL Quiet mode
  # -Y    - SASL mechanism to lo into without dn and pw, but with unix uid of the caller
  # -LLL:
  # -L    - print responses in LDIFv1 format instead of "extended LDIF"
  # -LL   - print responses in LDIF format without comments
  # -LLL  - without LDIF version line
  # -H    - Host
  # -b    - base
  searchResult="$(ldapsearch -Q -Y EXTERNAL -LLL \
    -H "${connectTo}" \
    -b "${searchBase}" \
    "${searchFilter}" \
    "${wantedAttribute}" \
    2>/dev/null || true)"

  extractDNs "${searchResult}"
}

# Replaces olcRootPW of the given entry. Returns the status of ldapmodify
function writeRootPasswordHash() {
  local entryDN="$1"
  local hashValue="$2"

  # Write to ldap
  # -Q - SASL Quiet mode
  # -Y - SASL mechanism to log in without dn and pw, but with unix uid of the caller
  # -H - Host
  # dn:         which entry to change
  # changetype: modify attributes of an existing entry
  # replace:    set the attribute, also works when it does not exist yet
  ldapmodify -Q -Y EXTERNAL -H ldapi:/// <<EOF
dn: ${entryDN}
changetype: modify
replace: olcRootPW
olcRootPW: ${hashValue}
EOF
}

function applyRootPassword() {
  local backendDN
  local rootPassword
  local passwordHash
  local passwordSource

  backendDN="$(findBackendDatabaseDN)"
  if [[ -z "${backendDN}" ]]; then
    echo "[ROOT-PASSWORD] WARN: no backend database found for suffix '${OPENLDAP_SUFFIX}'; skipping root password handling" >&2
    return 0
  fi

  if rootPassword="$(doguctl config --encrypted rootpwd)"; then
    passwordSource="configured"
    echo "[ROOT-PASSWORD] Applying the configured 'rootpwd' to ${backendDN}"
  else
    rootPassword="$(doguctl random)"
    passwordSource="generated"
    echo "[ROOT-PASSWORD] Rotating olcRootPW to replace a potentially insecure value on ${backendDN}"
  fi

  # -s - read the plaintext, salted.
  # The same plaintext hashes different every time, so a changed hash proves a
  # write event happened but not a different password was created.
  # NOT optional, because the config volume is declared "NeedsBackup" in
  # dogu.json, so an unhashed value would land in every backup. So:

  # hash the root password
  passwordHash="$(slappasswd -s "${rootPassword}")"
  unset rootPassword

  if ! writeRootPasswordHash "${backendDN}" "${passwordHash}"; then
    echo "[ROOT-PASSWORD] WARN: failed to write olcRootPW (${passwordSource}) to ${backendDN}; continuing startup" >&2
    return 0
  fi

  echo "[ROOT-PASSWORD] olcRootPW successfully set from ${passwordSource} source"
}
