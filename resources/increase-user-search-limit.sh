
function increaseUserSearchLimit() {
  config_search_limit=$(doguctl config user_search_size_limit)
  echo "#DOGU config_search_limit is ${config_search_limit}"
  if ldapsearch -b "cn=config" "(olcDatabase=*)" 2>/dev/null | grep olcSizeLimit >/dev/null; then
    echo "[INCREASE-USER-SEARCH-LIMIT] increasing user search limit"
    ldapmodify <<EOF
dn: olcDatabase={-1}frontend,cn=config
changetype: modify
replace: olcSizeLimit
olcSizeLimit: $config_search_limit
EOF
fi

}