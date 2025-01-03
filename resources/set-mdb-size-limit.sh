
function setMdbSizeLimit() {
  mdb_size_limit=$(doguctl config max_db_size)
  echo "#DOGU max_db_size is ${mdb_size_limit}"

  # Retrieve the current size limit
  current_size_limit=$(ldapsearch -b olcDatabase={1}mdb,cn=config | grep olcDbMaxSize | awk '{print $2}') || current_size_limit=0
  current_size_limit=${current_size_limit:-0}

  if [ "$mdb_size_limit" -gt "$current_size_limit" ]; then
    if [ "$current_size_limit" -eq "0" ]; then
      echo "[SET-MDB-DB-SIZE-LIMIT] No current size limit found. Setting new limit."
    else
      echo "[SET-MDB-DB-SIZE-LIMIT] Updating database size limit to ($mdb_size_limit)."
    fi

    ldapmodify <<EOF
dn: olcDatabase={1}mdb,cn=config
changetype: modify
replace: olcDbMaxSize
olcDbMaxSize: $mdb_size_limit
EOF

  else
    echo "[SET-MDB-DB-SIZE-LIMIT] Current size limit ($current_size_limit) is greater than or equal to the new limit ($mdb_size_limit). No changes made."
  fi

  echo "[SET-MDB-DB-SIZE-LIMIT] Current maximum database size: $(ldapsearch -b olcDatabase={1}mdb,cn=config | grep olcDbMaxSize)"
}