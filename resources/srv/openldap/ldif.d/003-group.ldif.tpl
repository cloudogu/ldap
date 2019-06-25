# vim:set ft=ldif:
#
version: 1

dn: cn={{.Env.Get "MANAGER_GROUP" }},ou=Groups,o={{.Env.Get "LDAP_DOMAIN" }},{{.Env.Get "OPENLDAP_SUFFIX" }}
cn: {{.Env.Get "MANAGER_GROUP" }}
description: Members of the {{.Env.Get "MANAGER_GROUP" }} group have full access to the cloudogu administration applications
member: uid={{.Env.Get "ADMIN_USERNAME" }},ou=People,o={{.Env.Get "LDAP_DOMAIN" }},{{.Env.Get "OPENLDAP_SUFFIX" }}
member: cn=__dummy
objectClass: top
objectClass: groupOfNames

dn: cn={{.Env.Get "ADMIN_GROUP" }},ou=Groups,o={{.Env.Get "LDAP_DOMAIN" }},{{.Env.Get "OPENLDAP_SUFFIX" }}
cn: {{.Env.Get "ADMIN_GROUP" }}
description: This group grants administrative rights to all development applications of cloudogu
member: cn=__dummy
objectClass: top
objectClass: groupOfNames

