# vim:set ft=ldif:
#
version: 1

dn: {{.Env.Get "OPENLDAP_SUFFIX" }}
objectClass: top
objectClass: domain

dn: o={{.Env.Get "LDAP_DOMAIN" }},{{.Env.Get "OPENLDAP_SUFFIX" }}
o: {{.Env.Get "LDAP_DOMAIN" }}
objectClass: top
objectClass: organization
description: Root entry for domain {{.Env.Get "LDAP_DOMAIN" }}
