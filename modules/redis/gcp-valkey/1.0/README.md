# Redis — GCP Valkey (Memorystore, PSC)

A managed **Google Cloud Memorystore for Valkey** instance, reachable over
**Private Service Connect (PSC)**. The module provisions the instance, enables
the Memorystore API, and auto-creates PSC endpoints inside your VPC, then
exposes the resulting endpoint as a `@facets/redis` output.

- **Clouds:** gcp
- **Resources created:** `google_project_service.memorystore`, `google_memorystore_instance.main`
- **Output type:** `@facets/redis`

The instance connects through the PSC service connection policy passed as an
input — no manual IP reservation. Both single-primary (`CLUSTER_DISABLED`) and
Redis-Cluster-protocol (`CLUSTER`) topologies are supported.

---

## Architecture

```
   INPUTS                                      RESOURCES (main.tf)                 OUTPUT
   ─────────────────────────────────           ──────────────────────────         ──────────────────

   gcp_provider ─────────┐                     google_project_service              @facets/redis
   @facets/gcp_cloud_account                    .memorystore                        interfaces.cluster
     project_id            │  project/region        (enables API)                     host / port
                           ├────────────────►                                         endpoint
   network ───────────────┤                    google_memorystore_instance.main      auth_token (secret)
   @facets/gcp-network-details                    mode / engine_version              connection_string (secret)
     project_id, region,  │  network self-link      node_type / shards / replicas
     vpc_name/self_link   │                         transit_encryption (TLS)        attributes
                          │                          engine_configs (maxmemory,       mode
   service_connection_policy                          databases)                      database_count
   @facets/gcp_service_connection_policy             maintenance_policy               server_ca_certs (secret)
     name (PSC policy) ───┘                          automated_backup_config
                                                     desired_auto_created_endpoints
                                                        │  (PSC auto-connections)
                                                        ▼
                                              endpoints[].connections[].psc_auto_connection
                                              → pick PRIMARY, else DISCOVERY, else READER
                                              → host = ip_address, port = port
```

The module reads the PSC auto-created connections back off the instance and
selects, in order, the `CONNECTION_TYPE_PRIMARY`, then `DISCOVERY`, then
`READER` connection as the endpoint it publishes.

---

## Usage

```yaml
kind: redis
flavor: gcp-valkey
version: "1.0"
disabled: true
spec:
  version_config:
    engine_version: VALKEY_7_2
    mode: CLUSTER_DISABLED
  sizing:
    node_type: SHARED_CORE_NANO
    shard_count: 1
    replica_count: 0
  security:
    enable_tls: true
    authorization_mode: AUTH_DISABLED
  engine_config:
    database_count: 16
    maxmemory_policy: volatile-lru
  maintenance:
    day: MONDAY
    hour: 22
    minute: 0
  backup:
    enabled: false
    retention_days: 1
    start_hour: 21
```

---

## Inputs

| Input | Type | Required | Purpose |
|-------|------|----------|---------|
| `gcp_provider` | `@facets/gcp_cloud_account` | Yes | GCP project + `google` provider. Falls back to its `project_id` when the network omits one. |
| `network` | `@facets/gcp-network-details` | Yes | Supplies `project_id`, `region`, and the VPC (`vpc_name` or `vpc_self_link`) the PSC endpoints attach to. |
| `service_connection_policy` | `@facets/gcp_service_connection_policy` | Yes | The Memorystore PSC service connection policy. Its `name` is recorded as a label. |

## Spec

| Group | Field | Type / Enum | Default | Notes |
|-------|-------|-------------|---------|-------|
| `version_config` | `engine_version` | `VALKEY_7_2` / `VALKEY_8_0` / `VALKEY_9_0` | `VALKEY_7_2` | Valkey engine version. |
| | `mode` | `CLUSTER_DISABLED` / `CLUSTER` / `CLUSTER_ENABLED` | `CLUSTER_DISABLED` | Topology. `CLUSTER_ENABLED` is the REST spelling and is normalised to `CLUSTER`. Changing mode **replaces** the instance. |
| `sizing` | `node_type` | `SHARED_CORE_NANO` / `STANDARD_SMALL` / `HIGHMEM_MEDIUM` / `HIGHMEM_XLARGE` | `SHARED_CORE_NANO` | Node size. |
| | `shard_count` | integer (1–1) | `1` | `CLUSTER_DISABLED` allows exactly one shard; `CLUSTER` requires ≥ 1. |
| | `replica_count` | integer (0–2) | `0` | Replicas per shard. |
| `security` | `enable_tls` | boolean | `true` | On → `SERVER_AUTHENTICATION` transit encryption and `rediss://` scheme. |
| | `authorization_mode` | `AUTH_DISABLED` / `IAM_AUTH` | `AUTH_DISABLED` | Instance auth mode. |
| `engine_config` | `database_count` | integer (11–100) | `16` | Logical DB count. `CLUSTER_DISABLED` only — ignored (not sent) in cluster mode. Floor of 11 keeps DB index 10 available. |
| | `maxmemory_policy` | string | `volatile-lru` | Passed as `engine_configs.maxmemory-policy`. |
| `maintenance` | `day` | weekday enum | `MONDAY` | Weekly maintenance window, UTC. |
| | `hour` | integer (0–23) | `22` | |
| | `minute` | integer (0–0) | `0` | Must be 0 — the API accepts whole hours only. |
| `backup` | `enabled` | boolean | `false` | Daily automated backup. Off by default. |
| | `retention_days` | integer (1–365) | `1` | Backup retention. |
| | `start_hour` | integer (0–23) | `21` | Backup start hour, UTC (whole hours only). |

## Outputs — `@facets/redis`

### Interface `cluster`

| Field | Description |
|-------|-------------|
| `host` | PSC endpoint IP of the selected connection |
| `port` | PSC endpoint port |
| `endpoint` | `host:port` |
| `auth_token` | Auth token (secret). Currently always empty — the module does not emit a password. |
| `connection_string` | `rediss://host:port` (or `redis://` when TLS is off), secret |

`secrets: [auth_token, connection_string]`

### Attributes

| Field | Description |
|-------|-------------|
| `mode` | The instance's actual mode as reported by the provider |
| `database_count` | `1` in cluster mode, otherwise the configured `database_count` |
| `server_ca_certs` | Managed server CA certs (secret) when TLS is on; empty list otherwise |

`secrets: [server_ca_certs]`

---

## Notes

- **Changing `mode` replaces the instance.** The endpoint IP changes and all
  cached data is lost. Treat it as a rebuild, not an in-place edit.
- **Cluster mode has one logical database (db 0).** The `engine_configs.databases`
  key is omitted entirely on a cluster instance (setting it is a 400 from the
  API); `database_count` is reported as `1` there.
- **`CLUSTER_ENABLED` → `CLUSTER`.** The Terraform provider and gcloud accept only
  `CLUSTER` / `CLUSTER_DISABLED`; the REST/docs spelling `CLUSTER_ENABLED` is
  accepted in the blueprint and normalised before apply.
- **PSC endpoints are auto-created.** `desired_auto_created_endpoints` attaches
  the instance to the given network; the module reads the resulting
  `psc_auto_connection` back and publishes the primary (or discovery, or reader)
  connection.
- **Maintenance and backup times are whole hours.** `maintenance.minute` is
  pinned to 0 and the backup schedule has no minutes field; both are validated at
  plan time.
- **`deletion_protection_enabled = false`.** The instance can be destroyed by a
  blueprint change — no API-side delete guard.
- **TLS drives the scheme and CA certs.** With TLS on, connections use `rediss://`
  and `server_ca_certs` is populated; with TLS off, `redis://` and no certs.
- **Backups default OFF.** A pure cache can be rebuilt from source; enable
  backups explicitly if the data must survive a rebuild.
