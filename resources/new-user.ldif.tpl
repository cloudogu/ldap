dn: cn={{.Env.Get "USERNAME" }},ou={{.Env.Get "OU" }},o={{.Env.Get "LDAP_DOMAIN" }},{{.Env.Get "OPENLDAP_SUFFIX" }}
cn: {{.Env.Get "USERNAME" }}
objectClass: organizationalRole
objectClass: simpleSecurityObject
userPassword: {{.Env.Get "ENC_PASSWORD" }}
