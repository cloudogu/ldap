# sSMTP aliases
#
# Format:	local_account:outgoing_address:mailhub
#
# Example: root:your_login@your.domain:mailhub.your.domain[:port]
# where [:port] is an optional port number that defaults to 25.
root:{{ .Config.GetOrDefault "mail_sender" "ldap.dogu@cloudogu.com"}}:postfix
mailuser:{{ .Config.GetOrDefault "password_change/mail_sender" "ldap.dogu@cloudogu.com"}}:postfix
