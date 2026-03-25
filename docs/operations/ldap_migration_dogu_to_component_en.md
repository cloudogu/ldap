# LDAP Migration from Dogu to Component

This document describes how the migration from an existing LDAP dogu instance to the LDAP component works and how it is applied during operations.

## Goal and Result

The migration transfers the existing LDAP data from the dogu to the LDAP component so that an existing system can continue to operate without rebuilding user and group data.

After a successful migration:

- the LDAP component is running with the migrated data,
- the old LDAP dogu is stopped,
- the old LDAP dogu is set to `pauseReconciliation=true`,
- the automatic migration is not executed again.

The later uninstallation of the old LDAP dogu is not part of the automatic migration flow.
It is performed explicitly afterwards via the blueprint by setting the dogu to `absent: true`.

## Prerequisites

Before starting the migration, the following conditions must be met:

- the LDAP dogu exists in the cluster,
- the LDAP dogu PVC exists under the fixed name `ldap`,
- the LDAP component is installed or upgraded with the migration path enabled,
- `migration.enabled=true` is set in the chart,
- the global LDAP-relevant component configuration is set correctly, especially:
  - `globalConfig.configMapName`
  - `globalConfig.key`
  - `config.openldap_suffix`
- a target PVC for the LDAP component can be created by the StatefulSet.

## What Is Migrated

Only the LDAP database is migrated from the dogu.

Specifically:

- source path: `db` inside the LDAP dogu PVC
- target path: `db` inside the LDAP component PVC
- the migrated content is the MDB payload of the LDAP database
- the old dogu `cn=config` configuration is not migrated

Important:

- the LDAP component creates its own configuration,
- the migration copies only the actual LDAP data afterwards,
- the runtime path `run` is not copied.
- before the actual cutover, the migration validates that dogu and component use the same essential LDAP configuration.

## How the Migration Works Technically

The migration is implemented as a Helm hook in the LDAP chart and runs automatically on `post-install` and `post-upgrade`.

Important:

- during the first installation of the component, the StatefulSet may start briefly,
- the first hook job then deliberately scales the target StatefulSet down to `0`,
- after that, the data is copied and the target is started again.

There are two hook jobs:

1. `*-migration-stop-source`
   - validates the essential dogu and component configuration before the cutover,
   - sets the LDAP dogu to `spec.stopped=true`,
   - waits until the LDAP dogu pods are terminated,
   - then sets `spec.pauseReconciliation=true`,
   - scales the LDAP component StatefulSet down to `0`.

2. `*-migration-copy-and-start`
   - mounts the source and target PVCs,
   - copies the LDAP database from the dogu PVC into the component PVC,
   - sets the migration status to `done`,
   - starts the LDAP component StatefulSet again.

If the second job fails:

- the migration status is set to `failed`,
- the LDAP dogu is started again,
- `pauseReconciliation` is reset to `false`.

The configuration validation currently enforces these values as hard prerequisites:

- `domain`
- `openldap_suffix`

If either value differs, the migration is aborted before the LDAP dogu is stopped.

## Migration Status

The current status is stored in the ConfigMap `<release>-config` under the key `migrationPhase`.

Possible values:

| Value               | Meaning                                                  |
|---------------------|----------------------------------------------------------|
| `pending`           | Migration has not been completed yet.                    |
| `running`           | Migration is currently running.                          |
| `done`              | Migration completed successfully.                        |
| `failed`            | Migration failed.                                        |
| `skipped_no_source` | No source data was found, so no data copy was performed. |

Important:

- if the value is `done` or `skipped_no_source`, the migration jobs are not executed again on later upgrades,
- if the value is `failed`, the migration can be triggered again after the issue has been fixed by running another upgrade.

## Operational Usage

### Variant 1: Installation via Helm

The migration runs automatically when the LDAP component is installed or upgraded with migration enabled.

Example:

```bash
helm upgrade --install ldap k8s/helm \
  --namespace ecosystem \
  --set migration.enabled=true
```

Alternatively via the make target:

```bash
make helm-apply
```

### Variant 2: Installation via the Component CR

If the LDAP component is deployed via the component operator, the migration also runs automatically through the underlying Helm release.

Example:

```bash
make component-apply
```

### Variant 3: Usage via the LOP-IdP Umbrella Chart

If LDAP is part of the LOP-IdP umbrella chart, the migration is executed automatically when that umbrella chart is installed or upgraded, as long as `migration.enabled=true` is set for LDAP.

## Post-Checks

After a successful migration, at least the following checks should be performed:

```bash
kubectl -n ecosystem get dogu ldap -o jsonpath='{.spec.stopped}{"\n"}{.spec.pauseReconciliation}{"\n"}'
kubectl -n ecosystem get configmap ldap-config -o jsonpath='{.data.migrationPhase}{"\n"}'
kubectl -n ecosystem rollout status statefulset/ldap --timeout=300s
kubectl -n ecosystem get pod -l app.kubernetes.io/instance=ldap
```

Expected result:

- `spec.stopped=true`,
- `spec.pauseReconciliation=true`,
- `migrationPhase=done`,
- the StatefulSet `ldap` is `Ready`.

Note:

- successful hook jobs are deleted automatically,
- in the success case, post-checks are therefore done via the state of the dogu, ConfigMap, and StatefulSet,
- if a hook fails, the failed jobs remain and can be inspected via `kubectl logs job/...`.

In addition, the following functional checks should be performed:

- users are still present,
- groups are still present,
- login with known LDAP users still works,
- component service accounts exist and work correctly.

## Failure Case and Rollback

If the migration fails, the relevant automatic rollback path is:

- `migrationPhase=failed`,
- the LDAP dogu is started again,
- `pauseReconciliation` is reset to `false`.

Checks in the failure case:

```bash
kubectl -n ecosystem get dogu ldap -o jsonpath='{.spec.stopped}{"\n"}{.spec.pauseReconciliation}{"\n"}'
kubectl -n ecosystem get configmap ldap-config -o jsonpath='{.data.migrationPhase}{"\n"}'
kubectl -n ecosystem logs job/ldap-migration-stop-source
kubectl -n ecosystem logs job/ldap-migration-copy-and-start
```

Expected result after a failure in step 2:

- `spec.stopped=false`,
- `spec.pauseReconciliation=false`,
- `migrationPhase=failed`,
- the LDAP dogu is available again.

After the problem has been fixed, the migration can be triggered again by running another install or upgrade.

## Final State After a Successful Migration

After a successful migration, the old LDAP dogu intentionally remains in the cluster, but inactive:

- `stopped=true`
- `pauseReconciliation=true`

Only after the new state has been verified sufficiently should the old LDAP dogu be set to `absent: true` in the blueprint and then be uninstalled.

This cleanup step is intentionally separated from the automatic migration flow.
