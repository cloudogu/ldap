#! /bin/bash
export BATS_TEST_START_TIME="0"
export BATSLIB_FILE_PATH_REM=""
export BATSLIB_FILE_PATH_ADD=""

load '/workspace/target/bats_libs/bats-support/load.bash'
load '/workspace/target/bats_libs/bats-assert/load.bash'
load '/workspace/target/bats_libs/bats-mock/load.bash'
load '/workspace/target/bats_libs/bats-file/load.bash'

setup() {
  kubectl_mock="$(mock_create)"
  ln -s "${kubectl_mock}" "${BATS_TMPDIR}/kubectl"
  export PATH="${BATS_TMPDIR}:${PATH}"
}

teardown() {
  unset kubectl_mock
  unset cp_mock
  unset source_volume
  unset target_volume
  rm -f "${BATS_TMPDIR}/kubectl" "${BATS_TMPDIR}/cp"
}

@test "extract_yaml_scalar reads an unquoted top-level scalar" {
  run bash -c '
    . k8s/helm/files/migration/common.sh
    printf "%s\n" "domain: example.com" | extract_yaml_scalar domain
  '

  assert_success
  assert_output "example.com"
}

@test "extract_yaml_scalar trims whitespace and removes surrounding quotes" {
  run bash -c '
    . k8s/helm/files/migration/common.sh
    printf "%s\n" "openldap_suffix:   \"dc=example,dc=com\"   " | extract_yaml_scalar openldap_suffix
  '

  assert_success
  assert_output "dc=example,dc=com"
}

@test "validate_migration_configuration succeeds for matching domain and default suffix" {
  mock_set_status "${kubectl_mock}" 0
  mock_set_output "${kubectl_mock}" $'admin: ldap\n' 1
  mock_set_output "${kubectl_mock}" $'admin: component\n' 2
  mock_set_output "${kubectl_mock}" $'domain: example.com\n' 3
  mock_set_output "${kubectl_mock}" $'domain: example.com\n' 4

  run bash -c '
    export NAMESPACE=ecosystem
    export COMPONENT_CONFIGMAP_NAME=ldap-config
    . k8s/helm/files/migration/common.sh
    validate_migration_configuration global-config config.yaml
  '

  assert_success
  assert_line "[MIGRATION] Migration config validation succeeded for domain='example.com' and openldap_suffix='dc=cloudogu,dc=com'."
}

@test "validate_migration_configuration fails on domain mismatch" {
  mock_set_status "${kubectl_mock}" 0
  mock_set_output "${kubectl_mock}" $'openldap_suffix: dc=example,dc=com\n' 1
  mock_set_output "${kubectl_mock}" $'openldap_suffix: dc=example,dc=com\n' 2
  mock_set_output "${kubectl_mock}" $'domain: source.example\n' 3
  mock_set_output "${kubectl_mock}" $'domain: target.example\n' 4

  run bash -c '
    export NAMESPACE=ecosystem
    export COMPONENT_CONFIGMAP_NAME=ldap-config
    . k8s/helm/files/migration/common.sh
    validate_migration_configuration global-config config.yaml
  '

  assert_failure
  assert_line "[MIGRATION] Migration config validation failed: domain mismatch (dogu='source.example', component='target.example')."
}

@test "step 1 stops source dogu and scales target down on success" {
  mock_set_status "${kubectl_mock}" 0
  mock_set_output "${kubectl_mock}" $'openldap_suffix: dc=example,dc=com\n' 2
  mock_set_output "${kubectl_mock}" $'openldap_suffix: dc=example,dc=com\n' 3
  mock_set_output "${kubectl_mock}" $'domain: example.com\n' 4
  mock_set_output "${kubectl_mock}" $'domain: example.com\n' 5
  mock_set_output "${kubectl_mock}" "" 7
  mock_set_output "${kubectl_mock}" "" 10

  run env \
    NAMESPACE=ecosystem \
    COMPONENT_CONFIGMAP_NAME=ldap-config \
    TARGET_STATEFULSET_NAME=ldap \
    TARGET_POD_SELECTOR='app.kubernetes.io/instance=ldap,app.kubernetes.io/name=ldap' \
    TARGET_GLOBAL_CONFIGMAP_NAME=global-config \
    TARGET_GLOBAL_CONFIGMAP_KEY=config.yaml \
    COMMON_SH_PATH=k8s/helm/files/migration/common.sh \
    WAIT_TIMEOUT_SECONDS=1 \
    sh k8s/helm/files/migration/01-stop-source-and-prepare-target.sh

  assert_success
  assert_line "[MIGRATION-STEP1] Step 1 finished successfully."
  assert_equal "$(mock_get_call_num "${kubectl_mock}")" "10"
  assert_equal "$(mock_get_call_args "${kubectl_mock}" 1)" "ecosystem patch configmap/ldap-config --type merge -p {\"data\":{\"migrationPhase\":\"running\"}}"
  assert_equal "$(mock_get_call_args "${kubectl_mock}" 6)" "ecosystem patch dogus.k8s.cloudogu.com/ldap --type merge -p {\"spec\":{\"stopped\":true}}"
  assert_equal "$(mock_get_call_args "${kubectl_mock}" 8)" "ecosystem patch dogus.k8s.cloudogu.com/ldap --type merge -p {\"spec\":{\"pauseReconciliation\":true}}"
  assert_equal "$(mock_get_call_args "${kubectl_mock}" 9)" "ecosystem scale statefulset/ldap --replicas=0"
}

@test "step 1 sets migration phase failed when configuration validation fails" {
  mock_set_status "${kubectl_mock}" 0
  mock_set_output "${kubectl_mock}" $'openldap_suffix: dc=example,dc=com\n' 2
  mock_set_output "${kubectl_mock}" $'openldap_suffix: dc=example,dc=com\n' 3
  mock_set_output "${kubectl_mock}" $'domain: source.example\n' 4
  mock_set_output "${kubectl_mock}" $'domain: target.example\n' 5

  run env \
    NAMESPACE=ecosystem \
    COMPONENT_CONFIGMAP_NAME=ldap-config \
    TARGET_STATEFULSET_NAME=ldap \
    TARGET_POD_SELECTOR='app.kubernetes.io/instance=ldap,app.kubernetes.io/name=ldap' \
    TARGET_GLOBAL_CONFIGMAP_NAME=global-config \
    TARGET_GLOBAL_CONFIGMAP_KEY=config.yaml \
    COMMON_SH_PATH=k8s/helm/files/migration/common.sh \
    sh k8s/helm/files/migration/01-stop-source-and-prepare-target.sh

  assert_failure
  assert_line "[MIGRATION-STEP1] Migration config validation failed: domain mismatch (dogu='source.example', component='target.example')."
  assert_equal "$(mock_get_call_args "${kubectl_mock}" 6)" "ecosystem patch configmap/ldap-config --type merge -p {\"data\":{\"migrationPhase\":\"failed\"}}"
}

@test "step 2 fails when no source data exists" {
  source_volume="${BATS_TMPDIR}/source"
  target_volume="${BATS_TMPDIR}/target"
  mkdir -p "${source_volume}/db" "${target_volume}/db"

  mock_set_status "${kubectl_mock}" 0
  mock_set_output "${kubectl_mock}" "running" 1

  run env \
    NAMESPACE=ecosystem \
    COMPONENT_CONFIGMAP_NAME=ldap-config \
    TARGET_STATEFULSET_NAME=ldap \
    TARGET_REPLICAS=1 \
    SOURCE_VOLUME_PATH="${source_volume}" \
    TARGET_VOLUME_PATH="${target_volume}" \
    COMMON_SH_PATH=k8s/helm/files/migration/common.sh \
    sh k8s/helm/files/migration/02-migrate-and-start-component.sh

  assert_failure
  assert_line "[MIGRATION-STEP2] Source LDAP data missing: expected ${source_volume}/db/data.mdb"
  assert_equal "$(mock_get_call_args "${kubectl_mock}" 2)" "ecosystem patch configmap/ldap-config --type merge -p {\"data\":{\"migrationPhase\":\"failed\"}}"
  assert_equal "$(mock_get_call_args "${kubectl_mock}" 3)" "ecosystem patch dogus.k8s.cloudogu.com/ldap --type merge -p {\"spec\":{\"stopped\":false,\"pauseReconciliation\":false}}"
}

@test "step 2 only starts target when migration is already done" {
  mock_set_status "${kubectl_mock}" 0
  mock_set_output "${kubectl_mock}" "done" 1

  run env \
    NAMESPACE=ecosystem \
    COMPONENT_CONFIGMAP_NAME=ldap-config \
    TARGET_STATEFULSET_NAME=ldap \
    TARGET_REPLICAS=2 \
    SOURCE_VOLUME_PATH="${BATS_TMPDIR}/source" \
    TARGET_VOLUME_PATH="${BATS_TMPDIR}/target" \
    COMMON_SH_PATH=k8s/helm/files/migration/common.sh \
    sh k8s/helm/files/migration/02-migrate-and-start-component.sh

  assert_success
  assert_line "[MIGRATION-STEP2] Migration phase is 'done', ensure component is started."
  assert_equal "$(mock_get_call_num "${kubectl_mock}")" "2"
  assert_equal "$(mock_get_call_args "${kubectl_mock}" 2)" "ecosystem scale statefulset/ldap --replicas=2"
}

@test "step 2 copies source DB and marks migration done" {
  source_volume="${BATS_TMPDIR}/source"
  target_volume="${BATS_TMPDIR}/target"
  mkdir -p "${source_volume}/db/run" "${target_volume}/db"
  echo source-db > "${source_volume}/db/data.mdb"
  echo lockfile > "${source_volume}/db/lock.mdb"
  echo runtime > "${source_volume}/db/run/socket"
  echo stale > "${target_volume}/db/old-file"

  mock_set_status "${kubectl_mock}" 0
  mock_set_output "${kubectl_mock}" "running" 1

  run env \
    NAMESPACE=ecosystem \
    COMPONENT_CONFIGMAP_NAME=ldap-config \
    TARGET_STATEFULSET_NAME=ldap \
    TARGET_REPLICAS=1 \
    SOURCE_VOLUME_PATH="${source_volume}" \
    TARGET_VOLUME_PATH="${target_volume}" \
    COMMON_SH_PATH=k8s/helm/files/migration/common.sh \
    sh k8s/helm/files/migration/02-migrate-and-start-component.sh

  assert_success
  assert_line "[MIGRATION-STEP2] Step 2 finished successfully."
  assert_file_exist "${target_volume}/db/data.mdb"
  assert_file_exist "${target_volume}/db/lock.mdb"
  assert_file_not_exist "${target_volume}/db/old-file"
  assert_file_not_exist "${target_volume}/db/run/socket"
  assert_equal "$(mock_get_call_args "${kubectl_mock}" 2)" "ecosystem patch configmap/ldap-config --type merge -p {\"data\":{\"migrationPhase\":\"done\"}}"
  assert_equal "$(mock_get_call_args "${kubectl_mock}" 3)" "ecosystem scale statefulset/ldap --replicas=1"
}

@test "step 2 marks migration failed and restarts source dogu when copy result is invalid" {
  source_volume="${BATS_TMPDIR}/source"
  target_volume="${BATS_TMPDIR}/target"
  mkdir -p "${source_volume}/db" "${target_volume}/db"
  echo source-db > "${source_volume}/db/data.mdb"

  cp_mock="$(mock_create)"
  ln -s "${cp_mock}" "${BATS_TMPDIR}/cp"
  mock_set_status "${cp_mock}" 0

  mock_set_status "${kubectl_mock}" 0
  mock_set_output "${kubectl_mock}" "running" 1

  run env \
    NAMESPACE=ecosystem \
    COMPONENT_CONFIGMAP_NAME=ldap-config \
    TARGET_STATEFULSET_NAME=ldap \
    TARGET_REPLICAS=1 \
    SOURCE_VOLUME_PATH="${source_volume}" \
    TARGET_VOLUME_PATH="${target_volume}" \
    COMMON_SH_PATH=k8s/helm/files/migration/common.sh \
    sh k8s/helm/files/migration/02-migrate-and-start-component.sh

  assert_failure
  assert_line "[MIGRATION-STEP2] Expected target DB file missing after copy: ${target_volume}/db/data.mdb"
  assert_equal "$(mock_get_call_args "${kubectl_mock}" 2)" "ecosystem patch configmap/ldap-config --type merge -p {\"data\":{\"migrationPhase\":\"failed\"}}"
  assert_equal "$(mock_get_call_args "${kubectl_mock}" 3)" "ecosystem patch dogus.k8s.cloudogu.com/ldap --type merge -p {\"spec\":{\"stopped\":false,\"pauseReconciliation\":false}}"

  rm -f "${BATS_TMPDIR}/cp"
}
