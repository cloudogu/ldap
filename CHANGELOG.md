# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- upgrade to OpenLDAP 2.4.28
- change user's email address to be unique in the LDAP directory (#8)
   - existing user data are kept without change, even those with non-unique email addresses
   - updating a person's directory entry will lead to an error `some attributes not unique` if the (non-unique) email address is supposed to be kept
- Added modular makefiles
- Added automated release
- Added upgrade dogu step in Jenkinsfile
