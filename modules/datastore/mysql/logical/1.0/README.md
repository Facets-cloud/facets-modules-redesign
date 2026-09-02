# MySQL — Logical (Shared Instance)

A **logical MySQL database** hosted on an existing, shared physical instance.
This flavor **creates no cloud resources, declares no providers, and takes no
inputs** — it is a pure passthrough that re-exposes another MySQL datastore's
connection outputs, optionally re-targeting the connection string at a different
logical database.

**Use case:** staging / cost consolidation, where several logical databases
share one physical instance. The source is selected *per environment*, so the
same blueprint resource can point at different shared instances across
dev / staging / prod.

- **Clouds:** aws, gcp, azure
- **Resources created:** none
- **Output type:** `@facets/mysql` (identical contract to a real MySQL datastore)

---

## Architecture

```
   SOURCE (existing/shared MySQL)                 THIS logical resource
   another datastore in the blueprint             creates NOTHING · no providers · no inputs
   ┌──────────────────────────────┐               ┌────────────────────────────────────┐
   │ mysql "shared-mysql"          │   spec.source │ re-exposes the source's reader &     │
   │  interfaces.writer            │ ────────────► │ writer interfaces verbatim,          │
   │  interfaces.reader            │  (@facets/    │ EXCEPT connection_string + database, │
   │  attributes...                │   mysql)      │ rebuilt when database_name is set    │
   └──────────────────────────────┘               └───────────────────┬──────────────────┘
        ▲ override per-environment                                     ▼
        │ (dev / stg / prod)                                  output: @facets/mysql
                                                              interfaces.reader / .writer
```

### How `database_name` changes the output

```
   database_name UNSET  ──►  connection_string = <source's, unchanged>
                             database          = <source's>

   database_name SET    ──►  connection_string = mysql://<host>:<port>/<database_name>   (no credentials)
                             database          = <database_name>
```

---

## Usage

### Passthrough (re-expose a shared instance as-is)

```yaml
kind: mysql
flavor: logical
version: "1.0"
spec:
  source: ${mysql.shared-mysql.out}
```

### Target a specific logical database

```yaml
kind: mysql
flavor: logical
version: "1.0"
spec:
  source: ${mysql.shared-mysql.out}
  database_name: reporting            # ^[a-zA-Z][a-zA-Z0-9_]*$, 1–64 chars
```

---

## Inputs

**None.** No cloud account, no provider — the module only reads the outputs of
the datastore selected in `spec.source`.

## Spec

| Field | Required | Notes |
|-------|----------|-------|
| `source` | Yes | Existing/shared MySQL datastore to re-expose. Resolves to its full outputs (interfaces + attributes) via `x-ui-output-type: @facets/mysql`. Override per environment. |
| `database_name` | No | Logical database to target. When set, the re-emitted `connection_string` and `database` point at it; when empty, the source values pass through unchanged. Pattern `^[a-zA-Z][a-zA-Z0-9_]*$`, 1–64 chars. |

---

## Outputs — `@facets/mysql`

### Interfaces

Both `reader` and `writer` are re-exposed from the source:

| Field | Description |
|-------|-------------|
| `host` | Source host |
| `port` | Source port |
| `username` | Source username |
| `password` | Source password (secret) |
| `database` | `database_name` when set, else the source's database |
| `connection_string` | `mysql://host:port/<database_name>` when `database_name` is set (credential-free), else the source's connection string |

`secrets` are inherited from the source (default `[password, connection_string]`).

### Attributes

Passed through from the source datastore.

### Wiring into a service

```yaml
kind: service
flavor: aws
spec:
  env:
    DB_HOST: ${mysql.my-logical.out.interfaces.writer.host}
    DB_PORT: ${mysql.my-logical.out.interfaces.writer.port}
    DB_NAME: ${mysql.my-logical.out.interfaces.writer.database}
    DB_USER: ${mysql.my-logical.out.interfaces.writer.username}
    DB_PASS: ${mysql.my-logical.out.interfaces.writer.password}
```

---

## Notes

- **No resources, no destroy risk.** Nothing is provisioned; removing this
  resource just stops re-exposing the source. The shared instance is untouched.
- **Per-environment source.** `source` is override-able, so one logical resource
  targets different physical instances across environments.
- **Credential-free connection string.** Unlike some engines, the rebuilt MySQL
  connection string is `mysql://host:port/db` — wire `username` / `password`
  separately from the interface fields.
- **Reader vs writer.** Both are re-exposed independently; a source that
  separates primary and read replica keeps that separation here.
