dn: cn=listRule,ou=People,o={{.Env.Get "LDAP_DOMAIN" }},{{.Env.Get "OPENLDAP_SUFFIX" }}
objectClass: top
objectClass: vlvSearch
cn: listRule
vlvBase: ou=People,o={{.Env.Get "LDAP_DOMAIN" }},{{.Env.Get "OPENLDAP_SUFFIX" }}
vlvScope:  1
vlvFilter: (|(cn=%)(sn=%)(givenName=%))
