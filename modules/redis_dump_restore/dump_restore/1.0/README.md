# Redis Dump Restore

A **cross-cloud Redis / Valkey warm-copy runner**. It copies keys from a source
Redis into a target Redis inside a Kubernetes Job. Built for the AWS → GCP
migration where the target cache should be warmed from the source before cutover.
The source is read-only, and only explicitly configured target DB indexes can be
flushed or written.

Unlike a full replication, this is a **key-by-key warm copy** (`SCAN` → `DUMP` /
`PTTL` → `RESTORE`), with an optional `redis-shake` engine for large managed
Redis sources that block `SYNC`/`PSYNC`. Terraform installs nothing destructive
on apply — it only lays down suspended CronJobs, a scripts ConfigMap, and RBAC.
**All Redis work runs when you trigger an action.**

- **Clouds:** aws, gcp
- **Runs in:** the Kubernetes cluster supplied by the `@facets/kubernetes-details`
  input
- **Output type:** `@facets/k8s_resource` (the installed Job/CronJob set)

---

## Architecture

```
   SOURCE (read-only)                 K8s Job in the target cluster              TARGET
   Redis / Valkey                     (@facets/kubernetes-details)               Redis / Valkey
   ┌──────────────────┐               ┌──────────────────────────────┐          ┌──────────────────┐
   │ spec.source      │  SCAN + DUMP  │ dump_restore.sh               │ RESTORE  │ spec.target      │
   │  host/port       │  + PTTL       │  engine=shell (per key)       │ (+PTTL)  │  host/port       │
   │  auth_token/tls  │ ───────────► │   or engine=redis-shake        │ ───────► │  configured DBs  │
   │  source_db       │  (per dataset)│   (scan_reader)               │          │  only            │
   └──────────────────┘               └───────────────┬──────────────┘          └──────────────────┘
        ▲ never written                                │  checkpoints
        │                                              ▼
   connection read from                       state ConfigMap  <name>-state
   spec.source (env + config.sh)              (phase per dataset)

   Terraform installs (suspended, triggered via Actions):
     CronJobs: <name>-driver | -preflight | -verify | -poller   (schedule 0 0 31 2 *, suspend=true)
     ConfigMap <name>-scripts  (config.sh + dump_restore.sh)
     ServiceAccount + Role + RoleBinding   (skipped if options.existing_service_account_name is set)
```

Connection details, options, and the dataset list are rendered by Terraform into
`config.sh` and passed as env. Each action creates a **manual Job from the
matching CronJob**, injecting the mode by replacing the container args.

---

## Actions

All six are Kubernetes Tekton actions. Each spawns a one-off Job from a suspended
CronJob, waits for the pod, streams its logs, and reports Job success/failure.

| Action | Runs on | What it does |
|--------|---------|--------------|
| `preflight-checks-k8s` | `-preflight` | Read-only source + target checks (connectivity, DB key counts) without changing data. Refuses if the target DB is non-empty and reset is not allowed. |
| `dump-restore-k8s` | `-driver` | The warm copy. For each configured dataset it runs preflight → restore → verify: `SCAN` the source key pattern, `DUMP`+`PTTL` each key, `RESTORE` on the target. Source is read-only; a non-empty target requires `allow_target_reset`. |
| `reset-target-db-k8s` | `-driver` | `FLUSHDB` on **only configured target DB indexes**. Hard-guarded by `allow_target_reset=true` and by an assertion that the target DB is one this resource configures. |
| `verify-restore-k8s` | `-verify` | Compares per-DB key counts and sampled key presence between source and target. |
| `show-status-k8s` | `-poller` | Prints the module checkpoint state (per-dataset phase) from the state ConfigMap. |
| `debug-runner-k8s` | `-driver` | Launches a short-lived debug pod with `redis-cli` and full env, then prints the `kubectl exec` command to shell in. |

---

## Usage

```yaml
kind: redis_dump_restore
flavor: dump_restore
version: "1.0"
disabled: true          # enable only when you are ready to run actions
spec:
  source:
    host: my-source-redis.internal
    port: 6379
    auth_token: "${blueprint.self.secrets.SRC_REDIS_TOKEN}"   # or "" if none
    tls: false
  target:
    host: my-target-redis.internal
    port: 6379
    auth_token: "${blueprint.self.secrets.TGT_REDIS_TOKEN}"
    tls: false
  datasets:
    my-dataset:
      source_db: 0
      target_db: 0
      key_pattern: "*"
  image: redis:7.2-alpine
  namespace: default
  options:
    allow_target_reset: false
    require_empty_target: true
    restore_replace: false
    copy_ttl: true
    scan_count: 1000
    sample_limit: 25
    restore_engine: shell        # shell | redis-shake
```

For a large managed source that blocks `SYNC`/`PSYNC`, set
`options.restore_engine: redis-shake` and tune the `redis_shake_*` options.

---

## Inputs

| Input | Type | Purpose |
|-------|------|---------|
| `kubernetes_details` | `@facets/kubernetes-details` | The cluster to run the warm-copy Job in. Supplies the `kubernetes` and `helm` providers. |

## Spec

| Field | Required | Notes |
|-------|----------|-------|
| `source.host` | Yes | Source Redis/Valkey host. Read-only. |
| `source.port` | No | Default `6379`. |
| `source.auth_token` | No | Secret ref. Empty for no-auth. |
| `source.tls` | No | Default `false`. |
| `target.*` | Yes (host) | Same shape as source. Destructive ops require `allow_target_reset`. |
| `datasets` | No | Map of copy jobs. Each key needs `source_db`, `target_db`, `key_pattern`. DB indexes `0–255`; pattern default `*`. |
| `image` | No | Runner image with `redis-cli` or `valkey-cli` plus `sh`. Default `redis:7.2-alpine`. |
| `namespace` | No | Namespace for Jobs and state. Default `default`. |
| `options.allow_target_reset` | No | Default `false`. Lets `reset-target` `FLUSHDB` configured target DBs. |
| `options.require_empty_target` | No | Default `true`. Refuse restore into a non-empty target DB when reset is off. |
| `options.restore_replace` | No | Default `false`. Use `RESTORE ... REPLACE` for existing keys. |
| `options.copy_ttl` | No | Default `true`. Preserve source `PTTL`; persistent keys restore with TTL 0. |
| `options.scan_count` | No | Default `1000` (10–100000). `SCAN`/`--scan` batch size. |
| `options.sample_limit` | No | Default `25` (0–1000). Keys sampled during verify. |
| `options.command_timeout_seconds` | No | Default `15`. Timeout for bounded Redis commands (PING, DUMP, RESTORE, sampled EXISTS, …). |
| `options.restore_engine` | No | `shell` (default) uses `redis-cli DUMP/RESTORE` per key; `redis-shake` uses RedisShake `scan_reader`. |
| `options.redis_shake_bin` | No | Binary name/path when engine is `redis-shake`. Default `redis-shake`. |
| `options.redis_shake_download_url` | No | Optional release tarball URL; empty resolves the latest Linux archive for the pod arch. |
| `options.redis_shake_pipeline_count_limit` | No | Default `1024`. |
| `options.redis_shake_target_max_qps` | No | Default `100000`. |
| `options.redis_shake_log_level` | No | `debug` / `info` (default) / `warn`. |
| `options.redis_shake_ncpu` | No | Default `0` (runtime default). |
| `options.existing_service_account_name` | No | Reuse an existing SA; when set, the module creates no SA/Role/RoleBinding. |
| `slack.channel_id` / `slack.token_secret` | No | Present in the spec and wired into config/env, but the current runner script does not post to Slack (see Notes). |
| `tolerations` | No | Map of pod tolerations applied to every Job. |

---

## Outputs — `@facets/k8s_resource`

The installed Kubernetes resource set (CronJobs, scripts ConfigMap, RBAC).
Attributes: `resource_name`, `resource_namespace`. No interfaces.

---

## Notes

- **Warm copy, not replication.** This copies existing keys at run time
  (`SCAN` → `DUMP`/`PTTL` → `RESTORE`); it does not stream ongoing writes. Run it
  close to cutover, or re-run to top up (`restore_replace=true` to overwrite).
- **Source is never written.** Only DB indexes listed in `spec.datasets` are
  eligible targets, and any `FLUSHDB` is double-guarded (`allow_target_reset` +
  a "target DB is configured" assertion).
- **Two engines.** `shell` copies key-by-key with `redis-cli` — simple and
  dependency-free. `redis-shake` uses `scan_reader`, needed for large managed
  Redis sources that block `SYNC`/`PSYNC`; the binary is resolved on PATH or
  downloaded from `redis_shake_download_url`.
- **`run` chains preflight → restore → verify** across all datasets in one Job,
  unlike the Mongo/MySQL variants where `run` folds preflight/verify into the
  restore step.
- **Verify is approximate** — per-DB key counts plus a sampled key-presence check
  (`sample_limit`), not a full key-by-key diff.
- **State lives in a ConfigMap** (`<name>-state`), one entry per dataset. That is
  why the runner needs `get/create/patch/update` on configmaps.
- **Slack is inert here.** The `slack` spec fields are rendered into `config.sh`
  and env, but this runner script contains no Slack calls — configuring them has
  no effect (differs from the Mongo/MySQL variants, which do post).
- **CronJobs ship suspended** with an unreachable schedule (`0 0 31 2 *`, Feb 31);
  they only ever run via the Actions above.
