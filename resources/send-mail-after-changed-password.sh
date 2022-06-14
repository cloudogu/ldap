#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

# shellcheck disable=SC1091
source /scheduled_jobs.sh

log_debug "##########"
# Read start of the period from config file
START_OF_THE_PERIOD_CONF_FILE=/send-mail-after-changed-password_starting-period
if [ ! -f "$START_OF_THE_PERIOD_CONF_FILE" ]; then
  log_debug "${START_OF_THE_PERIOD_CONF_FILE} does not exist. Now create these"
  echo "START_OF_THE_PERIOD=$(date +%Y%m%d%H%M%S)" >${START_OF_THE_PERIOD_CONF_FILE}
fi
# shellcheck disable=SC1090
source ${START_OF_THE_PERIOD_CONF_FILE}

SCRIPT_START_DATE=$(date +%Y%m%d%H%M%S)
# Persist the start time of the script to be able to use this start point for the next script execution.
echo "START_OF_THE_PERIOD=${SCRIPT_START_DATE}" >${START_OF_THE_PERIOD_CONF_FILE}

log_debug "Start the detection of changed user passwords since ${START_OF_THE_PERIOD}. Script starting time is ${SCRIPT_START_DATE}"

# Configuration of the LDAP and of LDAP search
LDAP_DOMAIN="$(doguctl config --global domain)"
OPENLDAP_SUFFIX="dc=cloudogu,dc=com"

LDAP_HOSTURI="ldapi:///"
LDAP_SEARCHBASE="ou=people,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}"
LDAP_SEARCHFILTER="(&(uid=*)(objectClass=inetOrgPerson))"
LDAP_SEARCH_BIN="/usr/bin/ldapsearch"
ldap_param="-Y EXTERNAL -H ${LDAP_HOSTURI} -LLL -Q"

# Relevant LDAP attributes of a user
#   CN: Common name of the user
#   UID: User ID of the user
#   MAIL: E-mail address of the user
LDAP_CN_ATTR=cn
LDAP_UID_ATTR=uid
LDAP_MAIL_ATTR=mail

# Configuration of mail
MAIL_BIN="mail"

DEFAULT_MAIL_SUBJECT="Your password has been changed"
MAIL_SUBJECT="$(doguctl config --default "${DEFAULT_MAIL_SUBJECT}" "password_change/mail_subject")"

DEFAULT_MAIL_BODY="Hello %name,\n\n\
your password of your user %uid in the CES has been changed.\n\n\
Regards."
MAIL_BODY="$(doguctl config --default "${DEFAULT_MAIL_BODY}" "password_change/mail_text")"

# Configuration of temporary files
tmp_dir="/tmp/$$.checkldap.tmp"
result_file="${tmp_dir}/res.tmp.1"
buffer_file="${tmp_dir}/buf.tmp.1"

if [ -d ${tmp_dir} ]; then
  echo "Error : temporary directory exists (${tmp_dir})"
  exit 1
fi
mkdir ${tmp_dir}

# Determine all relevant LDAP entries and write them to a file.
# Of the entries, only the "dn" (distinguish name) is returned.
${LDAP_SEARCH_BIN} "${ldap_param}" -b "${LDAP_SEARCHBASE}" "${LDAP_SEARCHFILTER}" "dn" | grep -iE '^dn:' \
> ${result_file}

# Iterate over all entries found (=lines in file)
while read -r dnStr; do
  # The file can also contain blank lines. These can be skipped.
  if [ ! "${dnStr}" ]; then
    continue
  fi

  # cut 'dn'-prefix
  dn="$(echo "${dnStr}" | cut -d : -f 2)"

  # Read the dn (distinguish name) cn (common name), uid (user ID), e-mail address and password change date and write them to a file.
  ${LDAP_SEARCH_BIN} "${ldap_param}" -b "${dn}" \
  ${LDAP_CN_ATTR} ${LDAP_UID_ATTR} ${LDAP_MAIL_ATTR} pwdChangedTime \
  > ${buffer_file}

  # Convert returned values into variables
  uid="$(grep -w "${LDAP_UID_ATTR}:" ${buffer_file} | cut -d : -f 2 | sed "s/^ *//;s/ *$//")"
  name="$(grep -w "${LDAP_CN_ATTR}:" ${buffer_file} | cut -d : -f 2 | sed "s/^ *//;s/ *$//")"
  mail="$(grep -w "${LDAP_MAIL_ATTR}:" ${buffer_file} | cut -d : -f 2 | sed "s/^ *//;s/ *$//")"
  pwdChangedTime="$(grep -w "pwdChangedTime:" ${buffer_file} | cut -d : -f 2 | cut -c 1-15 | sed "s/^ *//;s/ *$//" || true)"

  # If the user does not have a password change date, proceed to the next entry.
  if [ ! "${pwdChangedTime}" ]; then
    continue
  fi

  # When the password change date has occurred after the relevant start of the period, send the user an e-mail with the info about the changed password
  if [[ ${pwdChangedTime} -ge ${START_OF_THE_PERIOD} && ${pwdChangedTime} -lt ${SCRIPT_START_DATE} ]]; then
    logmsg="${MAIL_BODY}"
    logmsg="$(echo -e "${logmsg}" | sed "s/%name/${name}/; s/%uid/${uid}/;")"
    echo "${logmsg}" | exec su - mailuser -c "${MAIL_BIN} -s \"${MAIL_SUBJECT}\" \"${mail}\"" >&2
    echo "The password of the user '$uid' has been changed on ${pwdChangedTime}. E-mail sent to the assigned address."
  fi
done <${result_file}

rm -rf ${tmp_dir}

log_debug "Finished the detection of changed user passwords."
log_debug "##########"
