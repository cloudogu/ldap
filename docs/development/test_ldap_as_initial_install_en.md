# Test local LDAP version as initial installation.

It is not or only very difficult to purge and reinstall LDAP.
However, it makes sense to test how LDAP behaves when it is initially installed or installed via the
CES setup. This is possible with a simple trick:

1. on a preinstalled CES build the LDAP version to be tested with `cesapp build .`.
2. find out the LDAP image ID (e.g. with `docker images`) and then export it with `docker save image-id > /vagrant/ldap.tar.gz`.
3. change to a CES, where the ces-setup has not run yet
4. import the old image with `docker load < /vagrant/ldap.tar.gz`.
5. find out the image id with `docker images
6. find out which is the latest LDAP release: https://github.com/cloudogu/ldap/releases
7. tagging the image: `docker tag <image-id> registry.cloudogu.com/official/ldap:<release-version>`.
8. running the CES setup

The Ces setup will try to always install the latest LDAP version.
When pulling the LDAP image, it will then (if the tag is set correctly) not pull the latest image, but use
the image we imported.
This should work in most cases, but if the dogu.json from the old LDAP version is not compatible with the
imported image (e.g. due to changed volumes), this procedure will not work.