# PostgreSQL Replication — Logical

Drives **PostgreSQL logical replication** from a source instance to a target
instance so a database can be migrated live — typically **AWS RDS → GCP Cloud
SQL**. It runs entirely as Kubernetes CronJobs and Jobs in the target cluster:
Terraform lays down the service account, RBAC, credential secrets, scripts, and
suspended CronJobs, and you advance the migration through phases with Tekton
**actions**. Replication is checkpointed per-database so any action is a safe
resume point.

- **Cloud:** gcp (the runner lives in the GKE cluster; the source can be any
  reachable PostgreSQL)
- **Input:** `@facets/kubernetes-details` (kubernetes + helm providers)
- **Output type:** `@facets/k8s_resource`
- **Resources created:** ServiceAccount, Role, RoleBinding, two Secrets, a
  scripts ConfigMap, and five CronJobs (driver, preflight, verify-parity,
  verify-lag, poller)

---

## Architecture

```
   SOURCE PostgreSQL                    THIS resource (in GKE)                      TARGET PostgreSQL
   (e.g. AWS RDS)                       Kubernetes Jobs / CronJobs                  (e.g. GCP Cloud SQL)
   ┌───────────────────┐               ┌──────────────────────────────────┐       ┌───────────────────┐
   │ publication +      │  logical      │ runner image (psql + pg_dump)      │       │ subscription +    │
   │ replication slot   │  replication  │  · replicate.sh orchestrator       │ apply │ copied schema +   │
   │ spec.source.*      │ ────────────► │  · phases: PREFLIGHT → PUBLISH →   │ ────► │ streamed changes  │
   │ admin + repl users │  (WAL stream) │    SCHEMA → LOAD → INDEX → STEADY   │       │ spec.target.*     │
   └───────────────────┘               │  · checkpoint ConfigMap (state)    │       └───────────────────┘
            ▲                           │  · mutation lock (one run at a time)│
            │                           └──────────────┬─────────────────────┘
            │                                          │ triggered by
   @facets/kubernetes-details ──► kubernetes/helm      ▼
   (which cluster to run in)                   Tekton actions (run, preflight,
                                               cutover, verify-*, status, …)
```

Terraform provisions everything **suspended** (the CronJobs have a "never" cron
schedule except `verify-lag` and `poller`). An **action** creates a one-off Job
from the matching CronJob, injects the mode via an env patch, streams its logs,
and waits for completion. State for each database lives in a `-state` ConfigMap,
so re-running an action picks up from the last completed phase.

### Migration phases

Each database advances through a fixed phase order, tracked in the state ConfigMap:

```
   PREFLIGHT ──► PUBLISH ──► SCHEMA ──► LOAD ──► INDEX ──► STEADY
   read-only     create      replay     initial   deferred   ongoing
   checks        publication schema on  table     indexes,   change
   on both       + repl slot target     copy      FKs,       streaming
   sides         on source              (COPY)    triggers
```

---

## Actions

Actions come from `actions.tf` and are exposed as Tekton Kubernetes actions on
the resource. Each creates a manual Job from a backing CronJob and runs one mode
of `replicate.sh`.

| Action | Backing CronJob | Params | What it does |
|--------|-----------------|--------|--------------|
| `run` | driver | — | Advance replication from the current checkpoint. This is the main drive and the **resume** path — re-run it to continue. |
| `run-selected` | driver | `dbs` | Advance only a comma-separated subset of databases. |
| `attach-existing` | driver | `confirm_existing_baseline`, `confirm_source_writes_frozen` | Start attach-only replication against an already parity-verified target, skipping schema reset and initial copy. |
| `rebaseline-selected` | driver | `dbs`, `rebaseline_id` | Rebuild replication for a subset after explicit cleanup. |
| `stop-selected` | driver | `dbs` | Cleanly stop replication for a subset without restarting phases. |
| `stop-all` | driver | — | Cleanly stop replication for all configured databases. |
| `preflight` | preflight | — | Read-only source and target checks; advances no phases. |
| `discover-roles` | preflight | — | Read-only discovery of source roles referenced by ownership and grants. Use its output to populate `target.login_roles`. |
| `match-grants` | driver | — | Replay source object grants and compatible role memberships onto existing target roles. |
| `match-grants-dryrun` | preflight | — | Print the grants and memberships that `match-grants` would apply, without applying. |
| `verify-parity` | verify-parity | — | Compare per-table row counts between source and target. |
| `verify-lag` | verify-lag | — | Report replication slot retention and subscription lag. |
| `cutover` / `cutover-hold` | driver | — | After replication is caught up, sync target sequences and disable the subscription without dropping it. |
| `resume` | driver | `confirm_no_target_writes` | Resume a cutover-held subscription after confirming no target writes happened while held. |
| `finalize-cutover` | driver | — | Finalize a cutover-held database: drop the target subscription and clean the source slot. |
| `status` | poller | — | Print the checkpoint ConfigMap and refresh the Slack tracker when configured. |
| `debug-shell` | driver | — | Launch a short-lived debug pod with the same image, env, RBAC, and network path — no replication runs. |

**Mutating vs read-only.** `preflight`, `discover-roles`, `match-grants-dryrun`,
`verify-parity`, `verify-lag`, and `status` are read-only. The rest mutate and
are gated by `options.allow_mutation`. A mutation lock in the state ConfigMap
ensures only one mutating action runs at a time.

---

## Usage

```yaml
kind: postgres_replication
flavor: logical
version: "1.1"
disabled: false
spec:
  databases:
    my_db:
      source_db: my_db
      target_db: my_db
      publication: my_db_pub
      subscription: my_db_sub
  image: "postgres:17-alpine"
  namespace: default
  options:
    allow_mutation: true
    allow_schema_reset: false
    defer_secondary_indexes: true
    fail_on_missing_replica_identity: true
    foreign_key_validation_mode: strict
    load_ready_timeout_seconds: 7200
    max_concurrent_databases: 2
    target_login_role_mode: manage
    target_autoresize_limit_gb: 100
    target_disk_gb: 10
  slack:
    channel_id: ""
    token_secret: ""
  source:
    host: source.example.com
    port: 5432
    admin_user: postgres
    admin_password: "<wire-a-secret>"
    repl_user: migration_repl
    repl_password: "<wire-a-secret>"
  target:
    host: 10.0.0.15
    port: 5432
    admin_user: postgres
    admin_password: "<wire-a-secret>"
    repl_user: migration_repl
    repl_password: "<wire-a-secret>"
  tolerations:
    my-node-pool:
      key: dedicated
      operator: Equal
      value: my-node-pool
      effect: NoSchedule
```

The `admin_password` and `repl_password` fields on both `source` and `target`
are **secret references** — wire them to Facets secrets, don't inline plaintext.

---

## Inputs

| Input | Type | Providers | Purpose |
|-------|------|-----------|---------|
| `kubernetes_details` | `@facets/kubernetes-details` | kubernetes, helm | The GKE cluster where the runner Jobs/CronJobs, secrets, and RBAC are created. |

---

## Spec

### Top level

| Field | Required | Notes |
|-------|----------|-------|
| `databases` | Yes | Map of database migrations. Key is an arbitrary name (`^[a-zA-Z0-9_-]+$`); value is the per-database config below. |
| `image` | No | Runner image with `psql` and `pg_dump`. Default `postgres:17-alpine`. |
| `namespace` | No | Kubernetes namespace for the jobs. Blank uses `default`. |
| `options` | No | Orchestration behavior; see below. |
| `slack` | No | Optional Slack tracker; see below. |
| `source` | Yes | Source PostgreSQL connection and roles; see below. |
| `target` | Yes | Target PostgreSQL connection, roles, and login roles; see below. |
| `tolerations` | No | Map of pod tolerations applied to all replication jobs (YAML editor). |

### `databases.<name>`

| Field | Required | Notes |
|-------|----------|-------|
| `source_db` | Yes | Database name on the source instance. |
| `target_db` | Yes | Database name on the target instance. |
| `publication` | Yes | PostgreSQL publication name to create on the source. |
| `subscription` | Yes | Subscription and replication slot name on the target. |
| `exclude_schemas` | No | Source schemas to exclude from the publication (e.g. extension or migration-tool metadata). |
| `exclude_tables` | No | Fully qualified tables to exclude, e.g. `public.old_backup_table`. |
| `exclude_extensions` | No | Source extensions to skip during target schema replay, e.g. `aws_commons`. Review before using. |
| `exclude_foreign_keys` | No | Fully qualified FK constraints (`schema.table.constraint`) to skip during replay. Review before using. |

### `source`

| Field | Required | Notes |
|-------|----------|-------|
| `host` | Yes | Source host or IP. |
| `port` | No | Source TCP port. Default 5432. |
| `admin_user` | Yes | Admin user, used only for publication and replication-role setup. |
| `admin_password` | Yes | Secret ref for the admin password. |
| `repl_user` | Yes | Replication role to create or reuse on the source. |
| `repl_password` | Yes | Secret ref for the replication password. |
| `auth_db` | No | Source database for admin authentication checks. Blank uses each `source_db`. |

### `target`

| Field | Required | Notes |
|-------|----------|-------|
| `host` | Yes | Target host or IP. |
| `port` | No | Target TCP port. Default 5432. |
| `admin_user` | Yes | Admin user for schema, subscription, and verification. |
| `admin_password` | Yes | Secret ref for the admin password. |
| `repl_user` | Yes | Reserved for future reverse-replication resources. |
| `repl_password` | Yes | Secret ref for the replication password. |
| `login_roles` | No | Static list of target login roles. Terraform generates passwords, exposes them as sensitive outputs, and the job creates/updates the roles on the target. |

### `options`

| Field | Default | Notes |
|-------|---------|-------|
| `allow_mutation` | `true` | Allow mutating actions (run, stop, rebaseline, cutover, resume, finalize). Set `false` to pre-stage a resource with only read-only actions. |
| `allow_schema_reset` | `false` | Allow SCHEMA to drop and recreate a non-empty target public schema. |
| `defer_secondary_indexes` | `true` | Create PK/unique constraints before load, then defer secondary indexes, FKs, and triggers. |
| `fail_on_missing_replica_identity` | `true` | Block preflight when a published table has no primary key or explicit replica identity. |
| `foreign_key_validation_mode` | `strict` | `strict` validates copied rows immediately; `not_valid` creates FKs as NOT VALID for later cleanup and validation. |
| `load_ready_timeout_seconds` | `7200` | Max seconds LOAD waits for the subscription table copy to finish. 60–86400. |
| `max_concurrent_databases` | `2` | Max databases processed in one run. 1–10. |
| `require_target_login_roles` | `true` | Block preflight when `target.login_roles` is empty. Set `false` only when no app login roles are needed. |
| `target_login_role_mode` | `manage` | `manage` creates missing roles and rotates existing passwords; `create_missing` only creates absent roles; `skip` disables role creation and password writes. |
| `target_autoresize_limit_gb` | `0` | Optional target autoresize limit for preflight headroom checks. |
| `target_disk_gb` | `0` | Optional target disk size for preflight headroom checks. |

### `slack`

| Field | Notes |
|-------|-------|
| `channel_id` | Optional Slack channel id for the tracker. Blank disables Slack updates. |
| `token_secret` | Optional Facets secret reference holding a Slack bot token (secret ref). |

---

## Outputs — `@facets/k8s_resource`

### Attributes

| Attribute | Description |
|-----------|-------------|
| `resource_name` | The sanitized resource name used as the base for all created objects. |
| `resource_namespace` | The namespace the jobs and secrets run in. |

### Additional output

| Output | Notes |
|--------|-------|
| `target_login_role_passwords` | Map of target login role → generated password. Marked **sensitive**. |

---

## Notes

- **Checkpointed and resumable.** Per-database phase state is stored in the
  `<name>-state` ConfigMap. Re-running `run` (or `run-selected`) resumes from the
  last completed phase — actions are safe to retry.
- **One mutation at a time.** A mutation lock in the state ConfigMap refuses a
  second mutating action while one is active. Read-only actions are never blocked.
- **Source/target must differ.** The runner refuses to proceed if the source and
  target hosts are identical, guarding against replicating a database onto itself.
- **Pre-staging.** Set `options.allow_mutation: false` to create the resource and
  run preflight/verify/status without any risk of mutating the target; flip it to
  `true` when ready to migrate.
- **Cutover flow.** Reach steady state, then `cutover` (hold: sync sequences,
  disable the subscription), verify no target writes, then `finalize-cutover` to
  drop the subscription and clean the source slot. `resume` un-holds if you need
  to keep replicating after a hold.
- **Login roles.** Run `discover-roles` to list source roles, add them to
  `target.login_roles`, and the job manages them per `target_login_role_mode`.
  Generated passwords surface in the `target_login_role_passwords` sensitive output.
- **Slack tracker.** When `slack.channel_id` and `slack.token_secret` are set the
  runner posts and refreshes a progress tracker. Prefer a `chat:write`-scoped bot
  token (see NOTES.md).
