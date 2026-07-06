# Vultr Managed PostgreSQL

Creates a Vultr managed PostgreSQL database with SSL/TLS and trusted-IP allow-listing. Produces `@facets/postgres`.

## Overview

Provisions a Vultr Managed Database running the PostgreSQL engine. The module exposes `writer` and `reader` connection interfaces (both pointing at the primary host; Vultr handles read scaling via separate read replicas). The database is protected from accidental deletion with `prevent_destroy`.

## Resources Created

- **vultr_database**: A managed PostgreSQL cluster (`database_engine = "pg"`)

## Required Configuration

- **PostgreSQL Version**: one of `13`, `14`, `15`, `16`, `17`
- **Database Plan** (`sizing.plan`): a Vultr managed-database plan slug encoding vCPU/RAM/disk and node count, e.g. `vultr-dbaas-hobbyist-cc-1-25-1` (list via `GET /v2/databases/plans`)
- **Trusted IPs** (optional): CIDRs permitted to connect; empty denies all external access

## Inputs

- **Vultr Cloud Account** (`@facets/vultr_cloud_account`): provides the Vultr provider and region

## Outputs

- `@facets/postgres` (default): `writer` and `reader` interfaces with `host`, `port`, `username`, `password`, `connection_string`

## Notes & Gotchas

- **Trusted IPs**: the database is reachable only from CIDRs in `network_access.trusted_ips`. Add your VKE node egress CIDRs to allow the cluster to connect.
- **SSL required**: connection strings include `sslmode=require`.
