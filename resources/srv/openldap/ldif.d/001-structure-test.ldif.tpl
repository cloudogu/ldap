# vim:set ft=ldif:
#
version: 1

dn: ou=People,o={{.Env.Get "LDAP_DOMAIN" }},{{.Env.Get "OPENLDAP_SUFFIX" }}
ou: People
description: Root entry for persons
objectClass: top
objectClass: organizationalUnit

dn: ou=Groups,o={{.Env.Get "LDAP_DOMAIN" }},{{.Env.Get "OPENLDAP_SUFFIX" }}
ou: Groups
description: Root entry for groups
objectClass: top
objectClass: organizationalUnit

dn: ou=Special Users,o={{.Env.Get "LDAP_DOMAIN" }},{{.Env.Get "OPENLDAP_SUFFIX" }}
ou: Special Users
description: Root entry for Special Users
objectClass: top
objectClass: organizationalUnit

dn: ou=Bind Users,o={{.Env.Get "LDAP_DOMAIN" }},{{.Env.Get "OPENLDAP_SUFFIX" }}
ou: Bind Users
description: Root entry for Bind Users
objectClass: top
objectClass: organizationalUnit

dn: ou=Policies,o={{.Env.Get "LDAP_DOMAIN" }},{{.Env.Get "OPENLDAP_SUFFIX" }}
ou: Policies
description: Root entry for policies
objectClass: top
objectClass: organizationalUnit
