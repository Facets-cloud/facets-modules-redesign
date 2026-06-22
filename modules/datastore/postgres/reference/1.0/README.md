# PostgreSQL Reference Module

![Version](https://img.shields.io/badge/version-1.0-blue) ![Cloud](https://img.shields.io/badge/cloud-AWS%20%7C%20GCP%20%7C%20Azure-lightgrey)

## Overview

This flavour creates **no cloud resources**. It is a pure passthrough that
references an existing PostgreSQL datastore (selected via `spec.source`) and
re-exposes its connection outputs under the `@facets/postgres` contract.

The primary use case is **staging DB consolidation**: modelling a logical
database that is co-located on a shared physical instance. A blueprint can
declare one logical `postgres` resource per service while every reference
points at the same shared instance — optionally re-targeting the connection
string at a different logical database name.

## Resources Created

None. `main.tf` declares no resources and no providers. The module is a
stateless transform over `var.instance.spec.source`.

## Spec

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `source` | `@facets/postgres` (via `x-ui-output-type`) | yes | The existing postgres datastore to reference. Resolves to the selected resource's full outputs (interfaces + attributes). Selectable per environment, so it is override-able. |
| `database_name` | string | no (override-only) | Logical database to target on the shared host. When set, the `connection_string` is rebuilt to point at this database; otherwise the source connection string passes through unchanged. |

## Outputs

Emits `@facets/postgres` with `reader` and `writer` interfaces
(`host`, `port`, `username`, `password`, `connection_string`, `secrets`)
carried over from the source. Any source `attributes` (e.g.
`db_instance_identifier`, `arn`) are passed through. This matches the output
contract of `aws-rds` and `aws-aurora`, so consumers cannot tell the
difference between a real instance and a reference.

## Connection string re-targeting

When `database_name` is set, both reader and writer `connection_string`
values are rebuilt as:

```
postgres://<source-username>:<source-password>@<source-host>:<source-port>/<database_name>
```

Credentials, host and port are inherited from the source; only the database
path segment is replaced. When `database_name` is unset, the source's own
`connection_string` is passed through verbatim.

## Use case: staging DB consolidation

In staging it is common to run a single shared physical PostgreSQL instance
and give each service its own logical database. Model this by:

1. Deploying one real postgres datastore (e.g. `aws-rds`) — the shared instance.
2. Adding a `postgres/reference` resource per service, with `spec.source`
   pointing (per environment, via `--flavor`/override) at the shared instance
   and `database_name` set to the service's logical database.

This keeps blueprints identical across environments while consolidating
physical infrastructure in non-production.
