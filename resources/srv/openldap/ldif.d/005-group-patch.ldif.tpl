dn: cn={{.GlobalConfig.GetOrDefault "manager_group" "cesManager" }},ou=Groups,o={{.Env.Get "LDAP_DOMAIN" }},{{.Env.Get "OPENLDAP_SUFFIX" }}
changetype: modify
replace: description
description: Diese Gruppe gewährt administrativen Zugriff auf die Nutzerverwaltung (User Management)

dn: cn={{.GlobalConfig.GetOrDefault "admin_group" "cesAdmin" }},ou=Groups,o={{.Env.Get "LDAP_DOMAIN" }},{{.Env.Get "OPENLDAP_SUFFIX" }}
changetype: modify
replace: description
description: Diese Gruppe gewährt administrativen Zugriff auf alle Applikationen außer der Nutzerverwaltung (User Management)