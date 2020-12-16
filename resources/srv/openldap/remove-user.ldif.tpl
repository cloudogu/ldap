dn: cn={{.Env.Get "USERNAME" }},ou={{.Env.Get "OU" }},o={{.Env.Get "LDAP_DOMAIN" }},{{.Env.Get "OPENLDAP_SUFFIX" }}
changeType: delete
