#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

function installSSSVLVIfNecessary() {
  if ! ldapsearch -b "cn=module{0},cn=config" 2>/dev/null | grep sssvlv >/dev/null; then
    echo "[SSS-VLV-INSTALL] install server side sorting virtual list view module"
    ldapadd <<EOF
dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: sssvlv
EOF
  fi

  if ! ldapsearch -b olcDatabase={1}mdb,cn=config 2>/dev/null | grep -i overlay | grep sssvlv >/dev/null; then
    echo "[SSS-VLV-INSTALL] add server side sorting virtual list view module"
    ldapadd <<EOF
dn: olcOverlay=sssvlv,olcDatabase={1}mdb,cn=config
objectClass: olcOverlayConfig
objectClass: olcSssVlvConfig
olcOverlay: sssvlv
olcSssVlvMax: 8
olcSssVlvMaxKeys: 5
EOF
  fi
}
