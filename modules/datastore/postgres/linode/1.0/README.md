# Linode Managed PostgreSQL

Creates a Linode (Akamai) managed PostgreSQL database using the v2 API. Produces the `@facets/postgres` output type (reader/writer connection interfaces).

## Overview

Provisions a managed PostgreSQL cluster (single node or 3-node HA). Connection details are exposed via the standard `@facets/postgres` reader and writer interfaces, making the database swappable with PostgreSQL modules on other clouds. SSL is required on connections.

## Resources Created

- **linode_database_postgresql_v2**: The managed PostgreSQL cluster (`prevent_destroy` enabled)

## Required Configuration

- **Version**: PostgreSQL major version (13–16)
- **Type**: Linode instance type (e.g. `g6-nanode-1`)
- **Cluster Size**: `1` (single) or `3` (HA)
- **Allowed CIDRs** (optional): IP allow-list for client access (empty denies external access — populate with your LKE node egress CIDRs to connect)

## Inputs

- **Linode Cloud Account** (`@facets/linode_cloud_account`): provides the Linode provider and region

## Outputs

- `@facets/postgres`: `writer` and `reader` interfaces with `host`, `port`, `username`, `password`, `connection_string`
