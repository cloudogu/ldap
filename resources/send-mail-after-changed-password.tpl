#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

echo "##########"
# Read start of the period from config file
START_OF_THE_PERIOD_CONF_FILE=/send-mail-after-changed-password_starting-period
if [ ! -f "$START_OF_THE_PERIOD_CONF_FILE" ]; then
    echo "${START_OF_THE_PERIOD_CONF_FILE} does not exist. Now create these"
    echo "START_OF_THE_PERIOD=$(date +%Y%m%d%H%M%S)" > ${START_OF_THE_PERIOD_CONF_FILE}
fi

source ${START_OF_THE_PERIOD_CONF_FILE}

SCRIPT_START_DATE=$(date +%Y%m%d%H%M%S)
# Persist the start time of the script to be able to use this start point for the next script execution.
echo "START_OF_THE_PERIOD=${SCRIPT_START_DATE}" > ${START_OF_THE_PERIOD_CONF_FILE}

echo "Start the detection of changed user passwords since ${START_OF_THE_PERIOD}. Script starting time is ${SCRIPT_START_DATE}"

# Configuration of the LDAP and of LDAP search
LDAP_HOSTURI="ldapi:///"
LDAP_SEARCHBASE="ou=people,o={{.Env.Get "LDAP_DOMAIN" }},{{.Env.Get "OPENLDAP_SUFFIX" }}"
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
MAIL_SUBJECT="{{ .Config.GetOrDefault "password_change/mail_subject" "Your password has been changed"}}"
MAIL_BODY="{{ .Config.GetOrDefault "password_change/mail_text" ""}}"

if [ -z "$MAIL_BODY" ]
then
  MAIL_BODY="Hello %name,\n\n\
your password of your user %uid in the CES has been changed.\n\n\
Regards."
fi

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
${LDAP_SEARCH_BIN} ${ldap_param} -b "${LDAP_SEARCHBASE}"  \
"${LDAP_SEARCHFILTER}" "dn"\
> ${result_file}

# Iterate over all entries found (=lines in file)
while read dnStr
do
    # The file can also contain blank lines. These can be skipped.
	if [ ! "${dnStr}" ]; then
	 	continue
	fi

  # cut 'dn'-prefix
  dn=`echo ${dnStr} | cut -d : -f 2`

  # Read the dn (distinguish name) cn (common name), uid (user ID), email address and password change date and write them to a file.
	${LDAP_SEARCH_BIN} ${ldap_param} -b "${dn}" \
	${LDAP_CN_ATTR} ${LDAP_UID_ATTR} ${LDAP_MAIL_ATTR} pwdChangedTime \
	> ${buffer_file}

  # Convert returned values into variables
	uid=`grep -w "${LDAP_UID_ATTR}:" ${buffer_file} | cut -d : -f 2 \
		| sed "s/^ *//;s/ *$//"`
	name=`grep -w "${LDAP_CN_ATTR}:" ${buffer_file} | cut -d : -f 2\
	 	| sed "s/^ *//;s/ *$//"`
	mail=`grep -w "${LDAP_MAIL_ATTR}:" ${buffer_file} | cut -d : -f 2 \
	 	| sed "s/^ *//;s/ *$//"`
	pwdChangedTime=`grep -w "pwdChangedTime:" ${buffer_file} \
	 	| cut -d : -f 2 | cut -c 1-15 | sed "s/^ *//;s/ *$//"`

  # If the user does not have a password change date, proceed to the next entry.
	if [ ! "${pwdChangedTime}" ]; then
	 	continue
  fi

  # When the password change date has occurred after the relevant start of the period, send the user an email with the info about the changed password
	if [[ ${pwdChangedTime} -ge ${START_OF_THE_PERIOD} && ${pwdChangedTime} -lt ${SCRIPT_START_DATE} ]]; then
    # TODO adapt
		logmsg="${MAIL_BODY}"
		logmsg=`echo -e ${logmsg} | sed "s/%name/${name}/; s/%uid/${uid}/;"`

		echo "${logmsg}" | ${MAIL_BIN} -s "${MAIL_SUBJECT}" ${mail} >&2

		echo "The password of the user '$uid' has been changed on ${pwdChangedTime}. E-mail sent to ${mail}"
	fi
done < ${result_file}

rm -rf ${tmp_dir}

echo "Finished the detection of changed user passwords."
echo "##########"

exit 0
