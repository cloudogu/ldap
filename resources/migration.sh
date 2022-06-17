function start_migration () {
  echo "[DOGU] Moving exports ..."	
  mkdir -p ${MIGRATION_TMP_DIR}
  cp /etc/openldap/slapd.d/config.ldif ${MIGRATION_TMP_DIR}
  cp /etc/openldap/slapd.d/data.ldif ${MIGRATION_TMP_DIR}

  echo "[DOGU] Changing config ..."
  sed -i '/back_bdb.so/d' ${MIGRATION_TMP_DIR}/config.ldif
  sed -i '/back_hdb.so/d' ${MIGRATION_TMP_DIR}/config.ldif
  sed -i 's/hdb/mdb/g' ${MIGRATION_TMP_DIR}/config.ldif
  sed -i 's/Hdb/Mdb/g' ${MIGRATION_TMP_DIR}/config.ldif
  sed -i '/olcDbCheckpoint/d' ${MIGRATION_TMP_DIR}/config.ldif
  sed -i '/set_cachesize/d' ${MIGRATION_TMP_DIR}/config.ldif
  sed -i '/set_lk_max_locks/d' ${MIGRATION_TMP_DIR}/config.ldif
  sed -i '/set_lk_max_objects/d' ${MIGRATION_TMP_DIR}/config.ldif
  sed -i '/set_lk_max_lockers/d' ${MIGRATION_TMP_DIR}/config.ldif
  sed -i '/dn: cn={4}ppolicy/,/^$/d' ${MIGRATION_TMP_DIR}/config.ldif

  echo "[DOGU] Cleanup config and db folders ..."
  rm -rf /etc/openldap/slapd.d/*
  rm -rf /var/lib/openldap/*

  echo "[DOGU] Importing dump ..."
  slapadd -n 0 -F /etc/openldap/slapd.d -l ${MIGRATION_TMP_DIR}/config.ldif
  slapadd -n 1 -F /etc/openldap/slapd.d -l ${MIGRATION_TMP_DIR}/data.ldif

  echo "[DOGU] Setting rights correctly ..."
  chmod -R 700 /etc/openldap/slapd.d
  chmod -R 700 /var/lib/openldap
  chown -R ldap:ldap /etc/openldap/slapd.d
  chown -R ldap:ldap /var/lib/openldap
}