# Password policies

A password policy is created in the LDAP-Dogu by default. This password policy is currently kept minimalist.

## Structure and retrieval of the default password policy

An organisational unit (OU) with corresponding names has been created in LDAP for policies. This is listed under
`dn: ou=Policies,o=ces.local,dc=cloudogu,dc=com`.

To retrieve all entries under the OU `Policies`, the following commands can be executed:

1. Calling the bash shell inside the LDAP Docker container: `docker exec -it ldap bash`.
2. Perform LDAP search: `ldapsearch -b "ou=Policies,o=ces.local,dc=cloudogu,dc=com"`<br>
   This command returns all entries that can be found below this entry as well as the entry itself. The Default Password
   Policy is subordinate to this entry.<br>
   The option `-b` specifies that the entry specified after the option is searched for.

## Contents of the Default Password Policy

The default password policy is structured as follows:

```
dn: cn=default,ou=Policies,o=ces.local,dc=cloudogu,dc=com
objectClass: person
objectClass: pwdPolicy
cn: default
sn: pwpolicy
pwdAttribute: userPassword
pwdMustChange: TRUE
```

The individual values have the following meaning:

* `dn`: `dn` is the abbreviation for `Distinguished Name` and uniquely identifies an entry. The DN represents an object
  in a hierarchical directory. The DN is written from the lower to the higher hierarchy levels from left to right. Thus,
  the `default` policy is under the `policies` OU.
* objectClass: The two object classes, `person` and `pwdPolicy` specify which attributes can be used. All values of the
  object class `person` and `pwdPolicy` can now be used here. The attributes `cn` and `sn`
  come from the object class `person`, the attributes `pwdAttribute` and `pwdMustChage` from the object class `pwpolicy`
  .<br>
  Although the two attributes `cn` and `sn` of the object class `person` are not mandatory, it is required that an entry
  has a structured (`STRUCTUAL`) object class. The object class `pwdPolicy` is merely an auxiliary class (`AUXILARY`)
  and is therefore not sufficient on its own.
* `cn`: `cn` is the abbreviation for 'Common Name' and has no special meaning in this context and is purely
  meta-information.
* `sn`: `sn` is the abbreviation for `surname` (last name) and has no special meaning in this context and is purely
  meta-information.
* `pwdAttribute`: Contains the name of the attribute to which the password policy is applied. In this case the password
  policy is applied to the user attribute `userPassword`.
* `pwdMustChange`: Specifies with the value `TRUE` that a user (technically an LDAP entry) must change its password if
  the attribute `pwdReset` is set to `TRUE` for it.<br>
  Both attributes only work in combination with each other. That is, if the value `pwdReset` is set for the user, the
  value `pwdMustChange` in the password policy is set to false, then the user does not have to change his password.

## Set the attribute for changing the user's password

In order to force the user to change his password after logging in, the value of the attribute `pwdReset` must be
explicitly set in the user's LDAP entry. This attribute is not automatically set when a new entry is created. set.

This attribute is used to indicate (when `TRUE`) that the password has been updated by an administrator and must be
changed by the user. However, if the user changes his or her password, the LDAP automatically removes the attribute.

The attribute `pwdReset` is a so-called `operational attribute`, which is not returned by default - e.g. during a search
with `ldapsearch`. In order to display the operational attributes in a search with `ldapsearch` with a `+` must be added
to the end of the search. For example, to display the entry of the admin user incl. operational attributes the following
command can be used:
`ldapsearch -b "uid=admin,ou=People,o=ces.local,dc=cloudogu,dc=com" +`
Other operational attributes are, for example, the creation date of the entry and the date of the last change.

### Set the `pwdReset` attribute manually for a user

To manually set the value of the `pwdReset` attribute for a user, the following `ldapmodify` command can be executed.
The command sets the `pwdReset` attribute for the user `admin` to `TRUE`, so that he has to change his password when
logging in.

```
ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
dn: uid=admin,ou=People,o=ces.local,dc=cloudogu,dc=com
changetype: modify
add: pwdReset
pwdReset: TRUE
EOF
```
## Linking the password policy to other entries

When installing the password policy module, a default entry can be specified. This entry is used if there is no specific
specification for certain entries.

The current password policy described above is the current default password policy. This applies to all entries. Since
there are no rules there that require automatic action, such as a password expiry date, this is unproblematic.

However, if additional password rules are added, the password policy may need to be adjusted so that it does not apply
to technical users and service accounts.