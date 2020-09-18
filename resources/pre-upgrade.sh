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

function add_unique_module(){
  ldapadd -Y EXTERNAL -H ldapi:/// <<EOS
    dn: cn=module{0},cn=config
    changetype: modify
    add: olcModuleLoad
    olcModuleLoad: {3}unique
EOS
}

######

echo "Running pre-upgrade script from Version ${FROM_VERSION}..."

if [[ ${FROM_VERSION} =~ ^2.4.4((4-5)|(7-1)|(4-4))$ ]]; then
  echo "Trying to import unique module..."
  IS_UNIQUE_IMPORTED=$(is_unique_module_imported)
  if [[ "${IS_UNIQUE_IMPORTED}" == "false" ]]; then
    echo "Adding unique module..."
    add_refint_module
  elif [[ "${IS_UNIQUE_IMPORTED}" == "true" ]]; then
    echo "Unique module is already imported."
  fi
  else
    echo "Error while adding unique module."
    exit 1
fi

doguctl config post_upgrade_running false
