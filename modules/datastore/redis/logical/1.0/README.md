# Redis — Logical (Shared Instance)

A **logical Redis datastore** hosted on an existing, shared physical instance.
This flavor **creates no cloud resources, declares no providers, and takes no
inputs** — it is a pure passthrough that re-exposes another Redis datastore's
connection outputs, optionally targeting a different **logical DB index** on the
shared instance.

**Use case:** staging / cost consolidation, where a logical cache points at a
shared physical instance, optionally isolated on its own DB index. The source is
selected *per environment*.

- **Clouds:** aws, gcp, azure
- **Resources created:** none
- **Output type:** `@facets/redis` (identical contract to a real Redis datastore)

---

## Architecture

```
   SOURCE (existing/shared Redis)                 THIS logical resource
   another datastore in the blueprint             creates NOTHING · no providers · no inputs
   ┌──────────────────────────────┐               ┌────────────────────────────────────┐
   │ redis "shared-redis"          │   spec.source │ re-exposes the source's cluster      │
   │  interfaces.cluster           │ ────────────► │ interface verbatim, with db_index    │
   │   endpoint, port, auth_token, │  (@facets/    │ appended to the connection_string    │
   │   connection_string           │   redis)      │                                      │
   └──────────────────────────────┘               └───────────────────┬──────────────────┘
        ▲ override per-environment                                     ▼
        │ (dev / stg / prod)                                  output: @facets/redis
                                                              interfaces.cluster
```

### How `db_index` changes the connection string

```
   source cluster.connection_string = redis://:<auth>@<host>:<port>     (no DB path)

   db_index = 0 (default) ──►  connection_string = redis://:<auth>@<host>:<port>/0
   db_index = 3           ──►  connection_string = redis://:<auth>@<host>:<port>/3
```

> Use a distinct `db_index` to separate this logical cache from others sharing
> the same physical instance. If the source did not expose a connection string,
> the output connection string is `null`.

---

## Usage

### Passthrough (default DB index 0)

```yaml
kind: redis
flavor: logical
version: "1.0"
spec:
  source: ${redis.shared-redis.out}
```

### Target a separate logical DB index

```yaml
kind: redis
flavor: logical
version: "1.0"
spec:
  source: ${redis.shared-redis.out}
  db_index: 3                          # 0–15
```

---

## Inputs

**None.** No cloud account, no provider — the module only reads the outputs of
the datastore selected in `spec.source`.

## Spec

| Field | Required | Default | Notes |
|-------|----------|---------|-------|
| `source` | Yes | — | Existing/shared Redis datastore to re-expose. Resolves to its full outputs via `x-ui-output-type: @facets/redis`. Override per environment. |
| `db_index` | No | `0` | Logical DB index (0–15) to target on the shared instance; reflected into the connection string. |

---

## Outputs — `@facets/redis`

### Interfaces

A single `cluster` interface, re-exposed from the source:

| Field | Description |
|-------|-------------|
| `endpoint` | Source endpoint |
| `port` | Source port |
| `auth_token` | Source auth token (secret) |
| `connection_string` | Source connection string with `/<db_index>` appended (`null` if the source exposed none) |

`secrets` are inherited from the source's cluster interface. `attributes` is
empty (a logical cache owns no cloud attributes).

### Wiring into a service

```yaml
kind: service
flavor: aws
spec:
  env:
    REDIS_URL:      ${redis.my-logical.out.interfaces.cluster.connection_string}
    REDIS_HOST:     ${redis.my-logical.out.interfaces.cluster.endpoint}
    REDIS_PORT:     ${redis.my-logical.out.interfaces.cluster.port}
```

---

## Notes

- **No resources, no destroy risk.** Nothing is provisioned; removing this
  resource just stops re-exposing the source. The shared instance is untouched.
- **Per-environment source.** `source` is override-able, so one logical resource
  targets different physical instances across environments.
- **DB index isolation, not security.** `db_index` separates keyspaces on a
  shared instance; it is not an access boundary. Anything with the connection
  can `SELECT` another index.
