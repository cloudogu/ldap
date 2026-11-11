#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

function installCespersonIfNecessary() {
  if ! ldapsearch -b "cn=schema,cn=config" '(&(objectClass=olcSchemaConfig)(cn=*cesperson))' 2>&1 | grep "numEntries: 1" &> /dev/null; then
    echo "Cesperson does not exist. Adding..."
    ldapadd -f /srv/openldap/schema/cesperson.ldif
  fi
}

function updateCespersonSchemaIfNecessary() {
  local schema schemaDN currentClass technicalAttribute updatedClass modifications
  local ldapDomain ldapSuffix users userModifications
  # Disable LDIF wrapping so each schema definition can be inspected as one line.
  schema=$(ldapsearch -LLL -o ldif-wrap=no -b "cn=schema,cn=config" \
    '(&(objectClass=olcSchemaConfig)(cn=*cesperson))' dn olcAttributeTypes olcObjectClasses) || return $?
  schemaDN=$(printf '%s\n' "${schema}" | sed -n 's/^dn: //p')

  if [[ -z "${schemaDN}" ]]; then
    echo "Cesperson schema does not exist; it will be installed during startup."
    return 0
  fi

  currentClass=$(printf '%s\n' "${schema}" | sed -n "/^olcObjectClasses: .*NAME 'cesperson'/s/^olcObjectClasses: //p")
  if [[ -z "${currentClass}" ]]; then
    echo "ERROR: Cesperson schema exists but its cesperson object class is missing." >&2
    return 1
  fi

  modifications=""
  if ! printf '%s\n' "${schema}" | grep -Eq "^olcAttributeTypes: .*NAME 'technical'"; then
    # Unfold the image's schema LDIF, including the split SINGLE-VALUE token.
    technicalAttribute=$(sed ':a;N;$!ba;s/\n //g' /srv/openldap/schema/cesperson.ldif \
      | sed -n "/^olcAttributeTypes: .*NAME 'technical'/s/^olcAttributeTypes: //p")
    if [[ -z "${technicalAttribute}" ]]; then
      echo "ERROR: Technical attribute definition is missing from cesperson.ldif." >&2
      return 1
    fi
    modifications="add: olcAttributeTypes
olcAttributeTypes: ${technicalAttribute}
-
"
  fi

  if ! printf '%s\n' "${currentClass}" | grep -Eq '(^|[[:space:]($])technical([[:space:]$)]|$)'; then
    # Preserve the existing class and its other optional attributes.
    updatedClass=$(printf '%s\n' "${currentClass}" | sed 's/)[[:space:]]*)[[:space:]]*$/ $ technical ) )/')
    if [[ "${updatedClass}" == "${currentClass}" ]]; then
      echo "ERROR: Cesperson object class has an unexpected format (expected a MAY list)." >&2
      return 1
    fi
    # Remove the server-assigned value index before adding the updated definition.
    updatedClass=$(printf '%s\n' "${updatedClass}" | sed 's/^{[0-9][0-9]*}//')
    modifications+="delete: olcObjectClasses
olcObjectClasses: ${currentClass}
-
add: olcObjectClasses
olcObjectClasses: ${updatedClass}
-
"
  fi

  if [[ -n "${modifications}" ]]; then
    echo "Updating cesperson schema for the technical attribute..."
    ldapmodify <<EOF || return $?
dn: ${schemaDN}
changetype: modify
${modifications}
EOF
  fi

  ldapDomain=$(doguctl config --global domain) || return $?
  ldapSuffix=$(doguctl config openldap_suffix --default "dc=cloudogu,dc=com") || return $?
  # Only initialize existing cesperson entries without a value; retain explicit TRUE/FALSE values.
  users=$(ldapsearch -LLL -o ldif-wrap=no -E pr=500/noprompt \
    -b "ou=People,o=${ldapDomain},${ldapSuffix}" \
    '(&(objectClass=cesperson)(!(technical=*)))' dn) || return $?
  userModifications=$(printf '%s\n' "${users}" | awk '
    function emit() {
      if (dn == "") return
      print dn
      print "changetype: modify"
      print "add: technical"
      print "technical: FALSE"
      print ""
      dn = ""
    }
    /^dn::? / { dn = $0 }
    /^$/ { emit() }
    END { emit() }
  ')

  if [[ -n "${userModifications}" ]]; then
    echo "Initializing existing cesperson users without technical attribute to FALSE..."
    # Keep DN lines as returned by ldapsearch, including base64-encoded DNs.
    ldapmodify <<EOF
${userModifications}
EOF
  fi
}
