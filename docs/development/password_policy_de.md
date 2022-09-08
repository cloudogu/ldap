# Wichtige Hinweise zur Installation der Password-Policy

Die Password-Policy hat verschiedene Bestandteile. Damit die Password-Policy korrekt funktioniert, müssen alle davon
in der richtigen Reihenfolge installiert werden. Dies geschieht in der `/install-pwd-policy.sh`.
Dort wird bei jedem Bestandteil einzeln abgefragt, ob es installiert ist. Falls nicht, wird es nachinstalliert.

# Laden des Moduls
Das Laden des Moduls ist nur in Version 2.4.x notwendig. In 2.6.x und höher ist dieses bereits fest im LDAP integriert
und muss/kann nicht mehr geladen werden. Dieser Schritt wurde aus dem Installations-Script entfernt.
Dennoch ist es wichtig zu erwähnen, falls später einmal an einer älteren Version des LDAPs Änderungen vorgenommen
werden müssen.

# Installation des Moduls
Damit die Password-Policy genutzt werden kann, muss das Password-Policy-Modul zusätzlich zum Laden noch installiert werden. 
Das geschieht über den Befehl:
```
ldapadd <<EOF
dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: ppolicy
EOF
```

# Policy-OU anlegen
Um Password-Policies angelegt zu können, muss eine Organizational Unit (OU) für Policies angelegt werden.
Das geschieht mit dem Befehl:
```
ldapadd <<EOF
dn: ou=Policies,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}
objectClass: organizationalUnit
objectClass: top
description: Root entry for policies
ou: Policies
EOF
```

Wichtig zu beachten: In dem Befehl sind Variablen enthalten (LDAP_DOMAIN bzw. OPENLDAP_SUFFIX) => definiert in der `startup.sh`.
Diese können je nach Umgebung variieren.

# Password-Policy Overlay
Außerdem ist es nötig das ppolicy-Overlay hinzugefügt wird.
Das geschieht über den Befehl:
```
ldapadd <<EOF
dn: olcOverlay=ppolicy,olcDatabase={1}mdb,cn=config
objectClass: olcOverlayConfig
objectClass: olcPPolicyConfig
olcOverlay: ppolicy
olcPPolicyDefault: cn=default,ou=Policies,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}
olcPPolicyHashCleartext: TRUE
EOF
```

Wichtig zu beachten ist, dass in diesem Befehl die Datenbank enthalten ist (`olcDatabase={1}mdb`). Dieser
Befehl muss beim Wechsel der Datenbank entsprechend angepasst werden (also "mdb" => "hdb").
Weiterhin ist es wichtig das in dem Befehl Variablen enthalten sind (LDAP_DOMAIN bzw. OPENLDAP_SUFFIX) => definiert in der `startup.sh`.
Diese können je nach Umgebung variieren.

# Default-Password-Policy
Nach der Konfiguration muss noch eine Default-Password-Policy angelegt werden.
Das geschieht mit diesem Befehl:
```
    ldapadd <<EOF
dn: cn=default,ou=Policies,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}
objectClass: person
objectClass: pwdPolicy
cn: default
sn: pwpolicy
pwdAttribute: userPassword
pwdMustChange: TRUE
EOF
```

Wichtig zu beachten: In dem Befehl sind Variablen enthalten (LDAP_DOMAIN bzw. OPENLDAP_SUFFIX) => definiert in der `startup.sh`.
Diese können je nach Umgebung variieren.
