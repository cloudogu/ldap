# vim:set ft=ldif:
#
version: 1

dn: uid={{.Env.Get "ADMIN_USERNAME" }},ou=People,o={{.Env.Get "LDAP_DOMAIN" }},{{.Env.Get "OPENLDAP_SUFFIX" }}
uid: {{.Env.Get "ADMIN_USERNAME" }}
description: CES Administrator
givenName: {{.Env.Get "ADMIN_GIVENNAME" }}
objectClass: top
objectClass: person
objectClass: organizationalPerson
objectClass: inetOrgPerson
objectClass: cesperson
sn: {{.Env.Get "ADMIN_SURNAME" }}
cn: {{.Env.Get "ADMIN_DISPLAYNAME" }}
displayName: {{.Env.Get "ADMIN_DISPLAYNAME" }}
mail: {{.Env.Get "ADMIN_MAIL" }}
userPassword: {{.Env.Get "ADMIN_PASSWORD_ENC" }}
external: FALSE
