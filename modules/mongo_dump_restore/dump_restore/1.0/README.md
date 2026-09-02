# Mongo Dump Restore

A **cross-cloud MongoDB / DocumentDB data-migration runner**. It dumps one or
more databases from a source Mongo/DocumentDB and restores them into a target
Mongo, streaming `mongodump --archive | mongorestore --archive` inside a
Kubernetes Job. Built for the AWS → GCP migration: a DocumentDB (or Atlas/Mongo)
source is read-only, and only explicitly configured target databases can be
touched.

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
   Mongo / DocumentDB                 (@facets/kubernetes-details)               Mongo
   ┌──────────────────┐               ┌──────────────────────────────┐          ┌──────────────────┐
   │ spec.source      │   mongodump   │ dump_restore.sh               │ mongo-   │ spec.target      │
   │  host/port/user  │ ─── archive ─►│  streams dump → restore       │ restore  │  host/port/user  │
   │  auth_database   │   (--gzip)    │  remaps ns: source_db→target_db│ ─archive►│  configured DBs  │
   │  tls / replicaSet│               │  per spec.databases entry     │          │  only            │
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

Connection details, options, and the database list are rendered by Terraform
into `config.sh` (non-secret) and passed as env (`SOURCE_ADMIN_PASSWORD`,
`TARGET_ADMIN_PASSWORD`, `SLACK_TOKEN`). Each action creates a **manual Job from
the matching CronJob**, injecting the mode via an `ACTION_MODE_OVERRIDE` env
patch.

---

## Actions

All six are Kubernetes Tekton actions. Each spawns a one-off Job from a suspended
CronJob, waits for the pod, streams its logs, and reports Job success/failure.

| Action | Runs on | What it does |
|--------|---------|--------------|
| `preflight-checks-k8s` | `-preflight` | Read-only source + target checks: connectivity/auth, source/target versions, collection and document inventory. Refuses if the target is non-empty and reset is not allowed. Changes no data. |
| `dump-restore-k8s` | `-driver` | The migration. For each configured database: dump source, restore into target. Source is read-only. If the target already has collections, it resets only when `allow_target_reset=true`, otherwise it verifies the existing copy instead. Ends with a verify. |
| `reset-target-db-k8s` | `-driver` | Drops **only configured target databases** (`db.dropDatabase()`). Hard-guarded by `allow_target_reset=true` and by an assertion that the target DB is one this resource configures. |
| `verify-restore-k8s` | `-verify` | Compares collection counts and document counts between source and target (accounting for excluded collections). |
| `show-status-k8s` | `-poller` | Prints the module checkpoint state (per-database phase) from the state ConfigMap. |
| `debug-runner-k8s` | `-driver` | Launches a short-lived debug pod with the runner image and full env, then prints the `kubectl exec` command to shell in. |

---

## Usage

```yaml
kind: mongo_dump_restore
flavor: dump_restore
version: "1.0"
disabled: true          # enable only when you are ready to run actions
spec:
  source:
    host: my-source-docdb.internal
    port: 27017
    admin_user: app_user
    admin_password: "${blueprint.self.secrets.SRC_MONGO_PASSWORD}"
    auth_database: admin
    tls: true
    tls_allow_invalid_certificates: true
  target:
    host: my-target-mongo.default.svc.cluster.local
    port: 27017
    admin_user: root
    admin_password: "${blueprint.self.secrets.TGT_MONGO_PASSWORD}"
    auth_database: admin
    tls: false
  databases:
    my-db:
      source_db: my-db
      target_db: my-db
      exclude_collections: []
      preserve_uuids: false
  image: alpine/mongosh:latest
  namespace: default
  options:
    allow_target_reset: false
    require_empty_target: true
    gzip: true
    num_parallel_collections: 4
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
| `source.host` | Yes | Source Mongo/DocumentDB host. Read-only. |
| `source.port` | No | Default `27017`. |
| `source.admin_user` | Yes | Source user. |
| `source.admin_password` | Yes | Secret ref. |
| `source.auth_database` | No | Default `admin`. |
| `source.tls` | No | Default `true`. |
| `source.tls_allow_invalid_certificates` | No | Default `true` (`tlsInsecure`). |
| `source.replica_set` | No | Adds `replicaSet` to the URI. |
| `source.extra_uri_options` | No | Extra URI query options, no leading `?`. |
| `target.*` | Yes (host/user/password) | Same shape as source. Defaults: `tls=false`, `tls_allow_invalid_certificates=false`. Destructive ops allowed only for configured target DBs, only when enabled. |
| `databases` | No | Map of jobs. Each key needs `source_db` + `target_db`; optional `exclude_collections[]`, `preserve_uuids` (default `false`). |
| `image` | No | Runner image with `mongosh`, `mongodump`, `mongorestore`, `jq`, `curl`, `bash`. Default `alpine/mongosh:latest`. |
| `namespace` | No | Namespace for Jobs and state. Default `default`. |
| `options.allow_target_reset` | No | Default `false`. Lets `run`/`reset-target` drop configured target DBs. |
| `options.require_empty_target` | No | Default `true`. Refuse restore into a non-empty target when reset is off. |
| `options.gzip` | No | Default `true`. Gzip the dump stream. |
| `options.num_parallel_collections` | No | Default `4` (1–32). |
| `options.existing_service_account_name` | No | Reuse an existing SA; when set, the module creates no SA/Role/RoleBinding. |
| `slack.channel_id` / `slack.token_secret` | No | Post a single, in-place-updated progress message to Slack. |
| `tolerations` | No | Map of pod tolerations applied to every Job. |

---

## Outputs — `@facets/k8s_resource`

The installed Kubernetes resource set (CronJobs, scripts ConfigMap, RBAC).
Attributes: `resource_name`, `resource_namespace`. No interfaces.

---

## Notes

- **Source is never written.** All source access is dump/read. Only databases
  listed in `spec.databases` are eligible targets, and any drop is
  double-guarded (`allow_target_reset` + a "target DB is configured" assertion).
- **Dump/restore is a single stream** — `mongodump --archive | mongorestore
  --archive` — with namespace remap (`--nsFrom source_db.* --nsTo target_db.*`),
  `--noOptionsRestore`, optional `--gzip` and `--preserveUUID`.
- **Idempotent re-runs.** If the target already has collections and reset is off,
  `run` verifies the existing copy instead of refusing or duplicating.
- **Verify is count-based** — collection count (minus excludes) and total
  document count must match; a mismatch fails the action.
- **State lives in a ConfigMap** (`<name>-state`), one entry per database with
  `phase`, `last_completed_phase`, `updated_at`, `last_error`. That is why the
  runner needs `get/create/patch/update` on configmaps.
- **Slack (optional).** With `slack.channel_id` + `slack.token_secret` set, the
  runner posts once and then edits that message in place on each run.
- **Runtime tool install.** The runner installs `jq`/`curl` at start if missing
  (apk/apt). On official Mongo images it disables expired Mongo apt repos first.
- **CronJobs ship suspended** with an unreachable schedule (`0 0 31 2 *`, Feb 31);
  they only ever run via the Actions above.
