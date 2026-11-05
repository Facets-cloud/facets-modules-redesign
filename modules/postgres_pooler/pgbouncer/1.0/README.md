# Postgres Pooler — PgBouncer

An **in-cluster PgBouncer connection pooler** that fronts an existing Postgres
`source`. It renders the writer and reader backends as **two independent
Deployments + Services** (one per plane), authenticates clients from a **static
userlist** (`scram-sha-256`), and re-publishes a drop-in `@facets/postgres`
output so consumers wire to the pooler exactly as they would to a real database.
It is portable Kubernetes — runs on EKS or GKE.

- **Clouds:** aws, gcp
- **Resources created:** `random_password.admin`, `terraform_data.preconditions`,
  and per-plane `kubernetes_secret_v1.plane`, `kubernetes_deployment_v1.plane`,
  `kubernetes_service_v1.plane`, `kubernetes_pod_disruption_budget_v1.plane`
  (PDB only when `replicas > 1`), plus `kubernetes_config_map_v1.metrics` when
  metrics are enabled.
- **Output type:** `@facets/postgres`

---

## Architecture

```
   INPUTS                              RESOURCES (main.tf, per plane)          OUTPUT
   ────────────────────────           ────────────────────────────────       ──────────────────

   kubernetes_details ──────┐         Secret  <name>-writer / <name>-reader   @facets/postgres
   @facets/kubernetes-details          pgbouncer.ini + userlist.txt            interfaces.writer
     (kubernetes provider)  │           [+ client-tls.pem] [+ exporter_dsn]      host = <name>-writer.<ns>
                            │                                                          .svc.cluster.local
   node_pool (optional) ────┤         Deployment  (replicas, HA)               port, username, password
   @facets/kubernetes_nodepool         pgbouncer container                     connection_string
     node_selector, taints  │           [+ pgbouncer-exporter sidecar]        interfaces.reader
                            │           [+ otel-collector sidecar]              (own plane, or collapses
   spec.source ────────────┘         Service  ClusterIP | internal-lb (NLB)      onto writer if no replica)
   @facets/postgres                   PodDisruptionBudget (minAvailable=1)
     interfaces.writer/reader                                                  attributes
     interfaces (host/port/user/pw)   ConfigMap  <name>-otelcol (metrics on)    arn, db_instance_identifier
     attributes (arn, identifier)                                              (passed through from source)
                                                                              external_writer/reader_endpoint
   [databases] * = host=<source> ──► pure host-routing, real dbname            (NLB DNS, internal-lb only)
```

Each plane's `pgbouncer.ini` uses a **wildcard `[databases]`** entry — the
client's requested database name is forwarded verbatim to the backend host, so
the two planes differ only by backend host (writer primary vs reader replica).

---

## Usage

```yaml
kind: postgres_pooler
flavor: pgbouncer
version: "1.0"
spec:
  source: ${postgres.my-db.out}          # the @facets/postgres datastore to pool
  pool_writer: true
  pool_reader: true
  pool_mode: transaction
  default_pool_size: 50
  min_pool_size: 10
  reserve_pool_size: 5
  max_db_connections: 300
  max_client_conn: 3000
  auth_type: scram-sha-256
  expose: clusterip
  listen_port: 5432
  namespace: default
  replicas: 2
  image: edoburu/pgbouncer:v1.25.2-p0
  client_tls:
    sslmode: allow
    cert: ${blueprint.secrets.my-client-cert}   # secret-ref; required when sslmode=require
  users:
    app_user:
      credential: ${blueprint.secrets.app-db-password}   # secret-ref
      max_user_connections: 100
      pool_mode: transaction
```

---

## Inputs

| Input | Type | Required | Purpose |
|-------|------|----------|---------|
| `kubernetes_details` | `@facets/kubernetes-details` | Yes | Target cluster; provides the `kubernetes` provider. |
| `node_pool` | `@facets/kubernetes_nodepool` | No | When wired, its `node_selector` pins the pods and its `taints` become tolerations (needed on GKE's dedicated, tainted pools). When absent, no `nodeSelector`/tolerations are set (fine on untainted AWS general nodes). |

## Spec

| Field | Type / Enum | Default | Notes |
|-------|-------------|---------|-------|
| `source` | `@facets/postgres` | — (**required**) | The Postgres datastore this pooler fronts. Resolves to that resource's full outputs (interfaces + attributes). |
| `pool_writer` | boolean | `true` | Render the writer plane pooling the source primary. |
| `pool_reader` | boolean | `true` | Render the reader plane. Skipped when the source has no reader distinct from the writer. |
| `pool_mode` | `session` / `transaction` / `statement` | `transaction` | Global pooling mode fallback. |
| `default_pool_size` | number (1–1000) | `50` | Server connections per (user,db). |
| `min_pool_size` | number (0–1000) | `10` | Idle server connections kept warm. |
| `reserve_pool_size` | number (0–1000) | `5` | Extra connections above `default_pool_size` under load. |
| `max_db_connections` | number (1–100000) | `300` | Max total server connections to the backend. |
| `max_client_conn` | number (1–100000) | `3000` | Max client connections accepted. |
| `auth_type` | `scram-sha-256` / `md5` | `scram-sha-256` | Client auth method against the static userlist. |
| `expose` | `clusterip` / `internal-lb` | `clusterip` | `clusterip` = in-cluster only. `internal-lb` = one internal AWS NLB per plane for out-of-cluster (ECS/VM) consumers. |
| `listen_port` | number (1–65535) | `5432` | Port both planes' Services listen on. |
| `namespace` | string | `default` | Namespace to deploy into. |
| `replicas` | number (1–10) | `2` | Pod replicas per plane. A PDB (minAvailable=1) is created when > 1. |
| `image` | string | `edoburu/pgbouncer:v1.25.2-p0` | PgBouncer container image. |
| `client_tls.sslmode` | `disable` / `allow` / `require` | `allow` | Client-side TLS mode. `require`/`verify` need a cert. |
| `client_tls.cert` | secret-ref | — | PEM bundle (server cert+key) for the client-facing TLS listener. |
| `users.<name>.credential` | secret-ref | — | The role's DB password; seeds the static userlist. |
| `users.<name>.max_user_connections` | number | inherit global | Per-user server-connection cap. |
| `users.<name>.pool_mode` | `session` / `transaction` / `statement` | inherit global | Per-user pool mode. |
| `writer` / `reader` | object (free-form) | `{}` | Per-plane overrides (e.g. `default_pool_size`, `pool_mode`); omitted keys inherit the globals. |
| `resources.*` | strings | `50m`/`500m` CPU, `64Mi`/`256Mi` mem | Pod requests/limits. |
| `health_checks.liveness.*` / `.readiness.*` | numbers | see facets.yaml | Probe tuning. |
| `dns_max_ttl` | number (0–3600) | `15` | Seconds PgBouncer caches the backend hostname. Lower reacts faster to failover. |
| `pkt_buf` | number (1024–65536) | `4096` | Internal packet buffer bytes. |
| `listen_backlog` | number (16–65535) | `128` | TCP accept queue depth. |
| `metrics.enabled` | boolean | `false` | Add pgbouncer-exporter + otel-collector sidecars. |
| `metrics.otlp_endpoint` | string | `""` | OTLP gRPC endpoint the collector pushes to. |
| `metrics.exporter_image` / `.collector_image` / `.exporter_port` / `.scrape_interval` | — | pinned defaults | Metrics pipeline tuning. |

## Outputs — `@facets/postgres`

### Interfaces `writer` / `reader`

| Field | Description |
|-------|-------------|
| `host` | The plane Service's **cluster DNS** (`<name>-<plane>.<namespace>.svc.cluster.local`), in every expose mode. `reader` collapses onto the pooled writer when there is no distinct reader plane. |
| `port` | `listen_port` |
| `username` | Passed through from the source's writer/reader |
| `password` | Passed through from the source (secret) |
| `connection_string` | `postgres://<pooled-host>:<port>` |

`secrets: [password]`

### Attributes

| Field | Description |
|-------|-------------|
| `arn` | Source's `arn`, passed through |
| `db_instance_identifier` | Source's identifier, passed through |
| `external_writer_endpoint` | Internal NLB `host:port` for out-of-cluster clients (`internal-lb` mode only; empty otherwise) |
| `external_reader_endpoint` | Reader NLB endpoint, or collapses onto the writer NLB |

---

## Notes

- **`interfaces.host` is always the plane Service's cluster DNS** — even in
  `internal-lb` mode. A `type=LoadBalancer` Service keeps its ClusterIP, so
  in-cluster consumers route ClusterIP → pod via kube-proxy and never traverse
  the NLB. Only out-of-cluster (ECS/VM) clients use the NLB, via the
  `external_*_endpoint` attributes. Flipping `expose` does not repoint any
  in-cluster consumer.
- **Static userlist, no bootstrap.** Auth is a static `userlist.txt` seeded from
  `users.*.credential` — no `auth_query`, no `pg_shadow`, no bootstrap Job. A
  generated admin user is added for the admin console (`SHOW POOLS` / `SHOW STATS`).
- **At least one user is required.** A precondition fails the apply when
  `spec.users` is empty, when `source` resolves no writer host, or when
  `client_tls.sslmode=require` without a cert — each with a clear message.
- **Reader plane is conditional.** It renders only when `pool_reader` is true
  **and** the source exposes a reader host genuinely distinct from the writer.
  On a replica-less source, `interfaces.reader` collapses onto the writer.
- **Backend TLS is always `require`** (`server_tls_sslmode = require` to the
  source). Client-side TLS is separate and controlled by `client_tls`.
- **`internal-lb` provisions one internal NLB per plane** via the AWS Load
  Balancer Controller (external mode, ip targets); the apply waits for the LB
  address so the NLB DNS can be read into the output. No LB sharing between planes.
- **Metrics sidecars are plain containers, off by default.** When enabled, each
  plane gets a pgbouncer-exporter (scrapes the admin console) and an
  otel-collector (pushes OTLP). They carry no readiness probe, so they don't gate
  pod readiness; a bad image would crash-loop, which is why images are pinned.
  Native sidecars are avoided because the platform's kubernetes provider (< 2.35)
  rejects `init_container` `restart_policy`.
- **Config-hash annotation** on the pod template rolls the Deployment when the
  rendered `pgbouncer.ini` or `userlist.txt` changes.
- **Deployment defaults reproduce the pre-existing pod spec.** Resources, probes,
  and the extra `[pgbouncer]` lines (`pkt_buf`, `listen_backlog`) render only
  when set away from their defaults, so an unchanged consumer gets a byte-identical
  ini and no needless rollout.
