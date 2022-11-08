# LDAP Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Fixed
- Prevent ldapsearch results from being cut after 79 characters (#31)

## [v2.6.2-2] - 2022-09-08
### Changed
- Make sure socket path exists and use default socket path for ldap connections at dogu startup as it was before 2.6.2-1
- Move migration logic from startup script to `post-upgrade.sh`

### Fixed
- Fixed hard to repair state of ldap dogu when upgrading from 2.4.48-3 => 2.4.58-3 => 2.6.2-x (#29)
- Make sure that all parts of the password policy are installed correctly at each startup (#29)

## [v2.6.2-1] - 2022-08-23

**THIS VERSION HAS BEEN REMOVED FROM REGISTRY. IT MAY CAUSES ERRORS THAT ARE HARD TO FIX**

### Changed
- Upgrade base image to 3.15.3-1
- Upgrade OpenLDAP to v2.6.2.-r0
- Added conversion database format from old hdb to mdb format
- Removed ppolicy schema due to deprecated status
- slapd socket connections corrected

## [v2.4.58-4] - 2022-07-25
### Fixed
- After updating from version 2.4.48-3, the Dogu ran into an error the first time it was started and then restarted (#26)
- After updating from version 2.4.48-3, the password policy was not available (#26)

## [v2.4.58-3] - 2022-06-14
### Added
- an e-mail notification whenever a users password has been changed by anyone (#21)

## [v2.4.58-2] - 2022-04-13
### Added
- a default password policy (#14)
  - This password policy is kept minimalistic. Only the setting of a flag for a mandatory resetting of the password is 
    configured.
  - By setting the attribute `PwdReset` to `true` for a user, he/she must change his/her password when logging in.
  - For detailed information on the password policy, see [password policy documentation](docs/operations/password-policy_en.md)

### Fixed
- During the first installation or during an installation after a `purge`, the Dogu did not start if no value is stored 
  for the admin user in the etcd (key `/config/ldap/admin_mail/`). (#19)

## [v2.4.58-1] - 2022-04-06
### Fixed
- fix service account creation and deletion with the generation of ldap and slapd config at every dogu start #17

### Changed
- Upgrade to ldap 2.4.58
- Upgrade base image to 3.14.3-1
- Upgrade zlib to fix CVE-2018-25032; #15

## [v2.4.48-4] - 2022-03-02
### Added
- volume `/etc/openldap/slapd.d` to store slapd configuration data (#4)

## [v2.4.48-3] - 2020-12-18
### Fixed
- missing template information for the remove service accounts command

## [v2.4.48-2] - 2020-12-16
### Added
- command to remove service accounts

## [v2.4.48-1] - 2020-10-06
### Changed
- upgrade to OpenLDAP 2.4.48
- change user's e-mail address to be unique in the LDAP directory (#8)
   - existing user data are kept without change, even those with non-unique e-mail addresses
   - updating a person's directory entry will lead to an error `some attributes not unique` if the (non-unique) e-mail address is supposed to be kept
- Added more dogu build safety via CI/CD
    - Added modular makefiles
    - Added automated release
    - Added upgrade dogu step in Jenkinsfile
