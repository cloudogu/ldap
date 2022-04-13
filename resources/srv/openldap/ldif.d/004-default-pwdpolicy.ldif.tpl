# vim:set ft=ldif:
#
version: 1

dn: cn=default,ou=Policies,o={{.Env.Get "LDAP_DOMAIN" }},{{.Env.Get "OPENLDAP_SUFFIX" }}
objectClass: person
objectClass: pwdPolicy
cn: default
sn: pwpolicy
pwdAttribute: userPassword
pwdMustChange: TRUE
