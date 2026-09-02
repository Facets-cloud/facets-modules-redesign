# MongoDB — Logical (Shared Instance)

A **logical MongoDB database** hosted on an existing, shared mongo / DocumentDB
instance. This flavor **creates no cloud resources, declares no providers, and
takes no inputs** — it is a pure passthrough that re-exposes another mongo
datastore's connection outputs, optionally injecting a different logical
database into the connection strings.

**Use case:** consolidating multiple logical databases onto a single physical
cluster (e.g. a shared staging DB). The source is selected *per environment*.

- **Clouds:** aws, gcp, azure
- **Resources created:** none
- **Output type:** `@facets/mongo` (identical contract to a real mongo datastore)

---

## Architecture

```
   SOURCE (existing/shared mongo/DocumentDB)      THIS logical resource
   another datastore in the blueprint             creates NOTHING · no providers · no inputs
   ┌──────────────────────────────┐               ┌────────────────────────────────────┐
   │ mongo "shared-mongo"          │   spec.source │ re-exposes writer / reader / cluster │
   │  interfaces.writer            │ ────────────► │ interfaces verbatim, with the logical│
   │  interfaces.reader            │  (@facets/    │ database spliced into each           │
   │  interfaces.cluster           │   mongo)      │ connection_string (tls/replicaSet    │
   │  attributes...                │               │ query params preserved)              │
   └──────────────────────────────┘               └───────────────────┬──────────────────┘
        ▲ override per-environment                                     ▼
        │ (dev / stg / prod)                                  output: @facets/mongo
                                                     interfaces.writer / .reader / .cluster
```

### How `database_name` is injected

```
   source connection_string = mongodb://user:pass@host:port/<db>?tls=true&replicaSet=rs0

   database_name UNSET  ──►  connection_string unchanged
   database_name SET    ──►  mongodb://user:pass@host:port/<database_name>?tls=true&replicaSet=rs0
                             (authority + query params kept; only the /<db> segment is replaced)
```

The `name` field on each interface is also set to `database_name` when provided.

---

## Usage

### Passthrough (re-expose a shared cluster as-is)

```yaml
kind: mongo
flavor: logical
version: "1.0"
spec:
  source: ${mongo.shared-mongo.out}
```

### Target a specific logical database

```yaml
kind: mongo
flavor: logical
version: "1.0"
spec:
  source: ${mongo.shared-mongo.out}
  database_name: app
```

---

## Inputs

**None.** No cloud account, no provider — the module only reads the outputs of
the datastore selected in `spec.source`.

## Spec

| Field | Required | Notes |
|-------|----------|-------|
| `source` | Yes | Existing/shared mongo/DocumentDB datastore to re-expose. Resolves to its full outputs (interfaces + attributes) via `x-ui-output-type: @facets/mongo`. Override per environment. |
| `database_name` | No | Logical database to target. When set, it is spliced into each connection string (preserving `tls` / `replicaSet` and other query params) and set as the interface `name`; when empty, source values pass through unchanged. |

---

## Outputs — `@facets/mongo`

### Interfaces

`writer`, `reader`, and `cluster` are re-exposed from the source:

| Field | writer / reader | cluster |
|-------|-----------------|---------|
| `host` / `port` | ✓ | — |
| `endpoint` | — | ✓ |
| `username` / `password` | ✓ (password secret) | ✓ (password secret) |
| `name` | `database_name` when set, else source name | — |
| `connection_string` | db-injected when `database_name` set, else source | same |

`secrets` are inherited from the source (default `[password, connection_string]`).
Absent source fields surface as `null`.

### Attributes

Passed through from the source datastore.

### Wiring into a service

```yaml
kind: service
flavor: aws
spec:
  env:
    MONGO_URL:  ${mongo.my-logical.out.interfaces.writer.connection_string}
    MONGO_USER: ${mongo.my-logical.out.interfaces.writer.username}
    MONGO_PASS: ${mongo.my-logical.out.interfaces.writer.password}
    MONGO_DB:   ${mongo.my-logical.out.interfaces.writer.name}
```

---

## Notes

- **No resources, no destroy risk.** Nothing is provisioned; removing this
  resource just stops re-exposing the source. The shared cluster is untouched.
- **Per-environment source.** `source` is override-able, so one logical resource
  targets different physical clusters across environments.
- **Query params preserved.** The db-injection keeps `tls`, `replicaSet`, and
  other `?...` parameters intact — important for DocumentDB / replica-set URIs.
- **Logical DB, not isolation.** A logical database on a shared cluster is not a
  security boundary; credentials that reach the cluster can reach other DBs.
