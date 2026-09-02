# MySQL Dump Restore

A **cross-cloud MySQL data-migration runner**. It dumps one or more databases
from a source MySQL and restores them into a target MySQL by streaming
`mysqldump | mysql` inside a Kubernetes Job. Built for the AWS → GCP migration:
the source is read-only, and only explicitly configured target databases can be
dropped or written.

Terraform installs nothing destructive on apply — it only lays down suspended
CronJobs, a scripts ConfigMap, and RBAC. **All database work runs when you
trigger an action.**

- **Clouds:** aws, gcp
- **Runs in:** the Kubernetes cluster supplied by the `@facets/kubernetes-details`
  input
- **Output type:** `@facets/k8s_resource` (the installed Job/CronJob set)

---

## Architecture

```
   SOURCE (read-only)                 K8s Job in the target cluster              TARGET
   MySQL                              (@facets/kubernetes-details)               MySQL
   ┌──────────────────┐               ┌──────────────────────────────┐          ┌──────────────────┐
   │ spec.source      │   mysqldump   │ dump_restore.sh               │  mysql   │ spec.target      │
   │  host/port/user  │ ── --single- ►│  strip DEFINER (sed)          │  client  │  host/port/user  │
   │                  │  transaction  │  force UTC session tz         │ ───────► │  configured DBs  │
   │                  │  gtid off     │  per spec.databases entry     │          │  only            │
   └──────────────────┘               └───────────────┬──────────────┘          └──────────────────┘
        ▲ never written                                │  checkpoints
        │                                              ▼
   connection read from                       state ConfigMap  <name>-state
   spec.source (env + config.sh)              (phase per database; optional Slack)

   Terraform installs (suspended, triggered via Actions):
     CronJobs: <name>-driver | -preflight | -verify | -poller   (schedule 0 0 31 2 *, suspend=true)
     ConfigMap <name>-scripts  (config.sh + dump_restore.sh)
     ServiceAccount + Role + RoleBinding   (skipped if options.existing_service_account_name is set)
```

Connection details, options, and the database list are rendered by Terraform into
`config.sh` (non-secret) and passed as env (`SOURCE_ADMIN_PASSWORD`,
`TARGET_ADMIN_PASSWORD`, `SLACK_TOKEN`). Each action creates a **manual Job from
the matching CronJob**, injecting the mode via an `ACTION_MODE_OVERRIDE` env
patch.

---

## Actions

All six are Kubernetes Tekton actions. Each spawns a one-off Job from a suspended
CronJob, waits for the pod, streams its logs, and reports Job success/failure.

| Action | Runs on | What it does |
|--------|---------|--------------|
| `preflight-checks-k8s` | `-preflight` | Read-only source + target checks: connectivity/auth, charset & collation match, `max_allowed_packet` floor, non-InnoDB table detection. Refuses on any mismatch unless the matching `allow_*` override is set. Changes no data. |
| `dump-restore-k8s` | `-driver` | The migration. For each configured database: dump source, strip DEFINERs, restore into target. Source is read-only. If the target already has tables, it resets only when `allow_target_reset=true`, otherwise it refuses. Ends with a verify. |
| `reset-target-db-k8s` | `-driver` | `DROP DATABASE IF EXISTS` + `CREATE DATABASE` for **only configured target databases**. Hard-guarded by `allow_target_reset=true` and by an assertion that the target DB is one this resource configures. |
| `verify-restore-k8s` | `-verify` | Compares table counts and row counts between source and target. |
| `show-status-k8s` | `-poller` | Prints the module checkpoint state (per-database phase) from the state ConfigMap. |
| `debug-runner-k8s` | `-driver` | Launches a short-lived debug pod with the runner image and full env, then prints the `kubectl exec` command to shell in. |

---

## Usage

```yaml
kind: mysql_dump_restore
flavor: dump_restore
version: "1.0"
disabled: true          # enable only when you are ready to run actions
spec:
  source:
    host: my-source-mysql.internal
    port: 3306
    admin_user: app_user
    admin_password: "${blueprint.self.secrets.SRC_MYSQL_PASSWORD}"
  target:
    host: my-target-mysql.internal
    port: 3306
    admin_user: root
    admin_password: "${blueprint.self.secrets.TGT_MYSQL_PASSWORD}"
  databases:
    my-db:
      source_db: my-db
      target_db: my-db
      exclude_tables: []
      include_routines: true
      include_triggers: true
      include_events: false
  image: mysql:8.4
  namespace: default
  options:
    allow_target_reset: false
    require_empty_target: true
    force_utc: true
    default_character_set: utf8mb4
    strip_definers: true
    existing_service_account_name: ""
  slack:
    channel_id: ""
    token_secret: ""
```

---

## Inputs

| Input | Type | Purpose |
|-------|------|---------|
| `kubernetes_details` | `@facets/kubernetes-details` | The cluster to run the migration Job in. Supplies the `kubernetes` and `helm` providers. |

## Spec

| Field | Required | Notes |
|-------|----------|-------|
| `source.host` | Yes | Source MySQL host. Read-only. |
| `source.port` | No | Default `3306`. |
| `source.admin_user` | Yes | Source user. |
| `source.admin_password` | Yes | Secret ref. |
| `target.*` | Yes (host/user/password) | Same shape as source. Destructive ops allowed only for configured target DBs, only when enabled. |
| `databases` | No | Map of jobs. Each key needs `source_db` + `target_db`; optional `exclude_tables[]` (`schema.table`), `include_routines` (default `true`), `include_triggers` (default `true`), `include_events` (default `false`). |
| `image` | No | Runner image with `mysql`, `mysqldump`, `sed`, `bash`. Default `mysql:8.4`. |
| `namespace` | No | Namespace for Jobs and state. Default `default`. |
| `options.allow_target_reset` | No | Default `false`. Lets `run`/`reset-target` drop configured target DBs. |
| `options.require_empty_target` | No | Default `true`. Refuse restore into a non-empty target when reset is off. |
| `options.force_utc` | No | Default `true`. Sets source and target session `time_zone` to `+00:00`. |
| `options.default_character_set` | No | `utf8mb4` (default) / `utf8` / `latin1`. Used when creating the target DB. |
| `options.allow_charset_mismatch` | No | Default `false`. Accept a source/target charset difference. |
| `options.allow_collation_mismatch` | No | Default `false`. Accept a collation difference. |
| `options.allow_non_innodb` | No | Default `false`. Non-InnoDB tables are not consistent under `--single-transaction`. |
| `options.strip_definers` | No | Default `true`. Remove `DEFINER=` clauses from dumped SQL (via `sed`). |
| `options.min_max_allowed_packet_bytes` | No | Default `67108864`. Target must meet this floor and match/exceed source. |
| `options.lock_timeout_seconds` | No | Default `60`. |
| `options.existing_service_account_name` | No | Reuse an existing SA; when set, the module creates no SA/Role/RoleBinding. |
| `slack.channel_id` / `slack.token_secret` | No | Post a single, in-place-updated progress message to Slack. |
| `tolerations` | No | Map of pod tolerations applied to every Job. |

---

## Outputs — `@facets/k8s_resource`

The installed Kubernetes resource set (CronJobs, scripts ConfigMap, RBAC).
Attributes: `resource_name`, `resource_namespace`. No interfaces.

---

## Notes

- **Source is never written.** All source access is `mysqldump`/read. Only
  databases listed in `spec.databases` are eligible targets, and any drop is
  double-guarded (`allow_target_reset` + a "target DB is configured" assertion).
- **Consistent dump.** `mysqldump --single-transaction --set-gtid-purged=OFF`,
  with `--routines`/`--triggers`/`--events` toggled per database. Non-InnoDB
  tables break single-transaction consistency, so preflight flags them unless
  `allow_non_innodb=true`.
- **DEFINER stripping.** By default `DEFINER=` clauses are removed from the dump
  stream so restore does not depend on source-side users existing on the target.
- **Preflight is protective.** Charset, collation, and `max_allowed_packet`
  mismatches refuse the run unless the matching `allow_*` override is set — this
  guards against silent data corruption on restore.
- **Restore into empty targets.** `run` creates the target DB if absent; if it
  already has tables it resets only with `allow_target_reset=true`, otherwise it
  refuses (stricter than the Mongo variant, which verifies instead).
- **Verify is count-based** — table count and row counts must match.
- **State lives in a ConfigMap** (`<name>-state`), one entry per database with
  `phase`, `last_completed_phase`, `updated_at`, `last_error`. That is why the
  runner needs `get/create/patch/update` on configmaps.
- **Slack (optional).** With `slack.channel_id` + `slack.token_secret` set, the
  runner posts once and then edits that message in place on each run.
- **CronJobs ship suspended** with an unreachable schedule (`0 0 31 2 *`, Feb 31);
  they only ever run via the Actions above.
