# Important notes on installing the password policy

The password policy has several components. In order for the Password policy to work correctly, all of them must be installed
must be installed in the correct order. This is done in `/install-pwd-policy.sh`.
There you will be asked for each component if it is installed. If not, it will be installed later.

# Loading the module
Loading the module is only necessary in version 2.4.x. In 2.6.x and higher it is already integrated in LDAP and must
and must/cannot be loaded any more. This step has been removed from the installation script.
Nevertheless it is important to mention, if later on changes have to be made to an older version of the LDAP.
have to be made.

# Installation of the module
In order for it to be used, the Password Policy module must be installed in addition to being loaded.
This is done with this command:
```
ldapadd <<EOF
dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: ppolicy
EOF
```

# Create policy OU
In order to create password policies, an Organizational Unit (OU) for policies must be created.
This is done with this command:
```
ldapadd <<EOF
dn: ou=Policies,o=${LDAP_DOMAIN},${OPENLDAP_SUFFIX}
objectClass: organizationalUnit
objectClass: top
description: Root entry for policies
ou: Policies
EOF
```

Important to note: The command contains variables (LDAP_DOMAIN or OPENLDAP_SUFFIX) => defined in `startup.sh`.
These may vary depending on the environment.

# Password-Policy Overlay
In order to fully use all the features of the password policy, the ppolicy overlay must be added.
This is done with this command:
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

It is important to note that the database is included in this command (`olcDatabase={1}mdb`). This
command must be adapted accordingly when changing the database.
Also: Variables are included in the command (LDAP_DOMAIN or OPENLDAP_SUFFIX) => defined in `startup.sh`.
These may vary depending on the environment.

# Default-Password-Policy
After the configuration, a default password policy must still be created.
This is done with this command:
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

Important to note: The command contains variables (LDAP_DOMAIN or OPENLDAP_SUFFIX) => defined in `startup.sh`.
These can vary depending on the environment.
