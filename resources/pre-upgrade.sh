#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

FROM_VERSION="${1}"
#TO_VERSION="${2}"
#WAIT_TIMEOUT=600
#CURL_LOG_LEVEL="--silent"

##### functions declaration

function is_unique_module_imported(){
  SEARCH_RESULT=$(ldapsearch -H ldapi:// -Y EXTERNAL -b "cn=config" -LLL -Q "olcModuleLoad=unique")
  if [ -z "${SEARCH_RESULT}" ]; then
    echo "false"
  fi
  echo "true"
}

function make_email_unique(){
  # Adding unique module
  ldapadd -Y EXTERNAL -H ldapi:/// <<EOS
    dn: cn=module{0},cn=config
    changetype: modify
    add: olcModuleLoad
    olcModuleLoad: {3}unique
EOS

  # Adding unique filter
  ldapadd -Y EXTERNAL -H ldapi:/// <<EOS
    # BACKEND UNIQUE OVERLAY
    dn: olcOverlay={3}unique,olcDatabase={1}hdb,cn=config
    objectClass: olcUniqueConfig
    objectClass: olcOverlayConfig
    objectClass: olcConfig
    objectClass: top
    olcOverlay: {3}unique
    olcUniqueURI: ldap:///?mail?sub
EOS
}

######

echo "Running pre-upgrade script from Version ${FROM_VERSION}..."

if [[ ${FROM_VERSION} =~ ^2.4.4((4-.*)|(7-.*)|(4-.*))$ ]]; then
  exit 0
  echo "Trying to import unique module..."
  apk add --update openldap-overlay-unique
  IS_UNIQUE_IMPORTED=$(is_unique_module_imported)
  if [[ "${IS_UNIQUE_IMPORTED}" == "false" ]]; then
    echo "Adding unique module..."
    make_email_unique
  elif [[ "${IS_UNIQUE_IMPORTED}" == "true" ]]; then
    echo "Unique module is already imported."
  else
    echo "Error while adding unique module."
    exit 1
  fi
fi

doguctl config post_upgrade_running false
