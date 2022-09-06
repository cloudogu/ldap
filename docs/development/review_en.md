# Important to note when reviewing the LDAP-Dogus.
The following things should **unconditionally** be tested when upgrading the LDAP-Dogus:
- Is it possible to upgrade from an older version directly to the new one? e.g. `2.4.48-3`.
  - If it is not possible, the upgrade must be prevented in the `pre-upgrade.sh` script!
- Are mails still sent after the password change to notify about it?
- Is it still possible to create & update users?
- Is it still possible to reset the password at the next login via CAS? (Select the checkbox for this when editing the user)
- Is it still possible to create service accounts?