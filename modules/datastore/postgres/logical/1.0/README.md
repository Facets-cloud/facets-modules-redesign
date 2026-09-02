# Postgres — Logical (Shared Instance)

A **logical PostgreSQL database** hosted on an existing, shared physical
instance. This flavor **creates no cloud resources, declares no providers, and
takes no inputs** — it is a pure passthrough that re-exposes another postgres
datastore's connection outputs, optionally re-targeting the connection string at
a different logical database.

**Use case:** staging / cost consolidation, where many logical databases share
one physical instance. Because the source is selected *per environment*, the same
blueprint resource can point at different shared instances across dev / staging /
prod.

- **Clouds:** aws, gcp, azure
- **Resources created:** none
- **Output type:** `@facets/postgres` (identical contract to a real postgres
  datastore, so consumers wire to it the same way)

---

## Architecture

```
   SOURCE (existing/shared postgres)              THIS logical resource
   another datastore in the blueprint             creates NOTHING · no providers · no inputs
   ┌──────────────────────────────┐               ┌────────────────────────────────────┐
   │ postgres "shared-pg"          │   spec.source │ re-exposes the source's reader &     │
   │  interfaces.writer            │ ────────────► │ writer interfaces verbatim,          │
   │  interfaces.reader            │  (@facets/    │ EXCEPT the connection_string, which  │
   │  attributes.arn, ...          │   postgres)   │ is rebuilt when database_name is set │
   └──────────────────────────────┘               └───────────────────┬──────────────────┘
        ▲ override per-environment                                     │
        │ (fans out to different shared                                ▼
        │  instances in dev / stg / prod)                    output: @facets/postgres
                                                              interfaces.reader / .writer
                                                              attributes (passed through)
```

### How `database_name` changes the connection string

```
   database_name UNSET  ──►  connection_string = <source's connection_string, unchanged>

   database_name SET    ──►  connection_string = postgres://<user>:<pass>@<host>:<port>/<database_name>
                             (rebuilt from the source's host/port/user/pass; credentials embedded)
```

> Note: when rebuilt, the connection string **embeds the username and password**.
> It is marked as a secret in the output (`secrets: [password, connection_string]`).

---

## Usage

### Passthrough (re-expose a shared instance as-is)

```yaml
kind: postgres
flavor: logical
version: "1.0"
spec:
  source: ${postgres.shared-pg.out}     # select the shared/source postgres resource
```

### Target a specific logical database

Override `database_name` (override-only field) — typically per environment:

```yaml
kind: postgres
flavor: logical
version: "1.0"
spec:
  source: ${postgres.shared-pg.out}
  database_name: reporting              # ^[a-zA-Z][a-zA-Z0-9_]*$, 1–63 chars
```

---

## Inputs

**None.** This flavor requires no cloud account and no provider — it only reads
the outputs of the datastore selected in `spec.source`.

## Spec

| Field | Required | Notes |
|-------|----------|-------|
| `source` | Yes | The existing/shared postgres datastore to re-expose. Resolves to that resource's full outputs (interfaces + attributes) via `x-ui-output-type: @facets/postgres`. Override per environment. |
| `database_name` | No (override-only) | Logical database to target. When set, the connection string is rebuilt to point at it; when empty, the source connection string passes through unchanged. Pattern `^[a-zA-Z][a-zA-Z0-9_]*$`, 1–63 chars. |

---

## Outputs — `@facets/postgres`

### Interfaces

Both `reader` and `writer` are re-exposed from the source (same fields):

| Field | Description |
|-------|-------------|
| `host` | Source host |
| `port` | Source port |
| `username` | Source username |
| `password` | Source password (secret) |
| `connection_string` | Source connection string, or `postgres://user:pass@host:port/<database_name>` when `database_name` is set (secret) |

`secrets: [password, connection_string]` on both interfaces.

### Attributes

Passed through from the source datastore when it emits them (e.g. `arn`,
`db_instance_identifier`). Empty if the source exposes none.

### Wiring into a service

```yaml
kind: service
flavor: aws
spec:
  env:
    DB_HOST: ${postgres.my-logical.out.interfaces.writer.host}
    DB_PORT: ${postgres.my-logical.out.interfaces.writer.port}
    DB_USER: ${postgres.my-logical.out.interfaces.writer.username}
    DB_PASS: ${postgres.my-logical.out.interfaces.writer.password}
    DB_URL:  ${postgres.my-logical.out.interfaces.writer.connection_string}
```

---

## Notes

- **No resources, no destroy risk.** Nothing is provisioned; removing this
  resource just stops re-exposing the source. The underlying shared instance is
  untouched.
- **Per-environment source.** `source` is override-able, so one logical resource
  can target different physical instances across environments.
- **Reader vs writer.** Both interfaces are re-exposed independently from the
  source's reader/writer — if the source separates them (e.g. a primary + read
  replica), that separation is preserved here.
```
