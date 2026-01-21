# PostgreSQL CloudSQL Database

[![Terraform](https://img.shields.io/badge/terraform-v1.5.7-blue.svg)](https://www.terraform.io)
[![Google Cloud](https://img.shields.io/badge/gcp-cloudsql-blue.svg)](https://cloud.google.com/sql)

## Overview

This module provisions a managed PostgreSQL database using Google Cloud SQL with enterprise-grade security, high availability, and automated backup capabilities. It provides a developer-friendly interface while maintaining production-ready defaults for encryption, networking, and disaster recovery.

## Environment as Dimension

The module is environment-aware and automatically configures:
- **Instance naming**: Incorporates environment unique identifiers to prevent conflicts
- **Resource tagging**: Applies environment-specific cloud tags for resource management
- **Network isolation**: Uses environment-specific VPC and subnet configurations
- **Backup retention**: Maintains consistent 7-day backup policy across environments

## Resources Created

- **Cloud SQL PostgreSQL Instance**: Primary database instance with regional availability
- **Private Database**: Default application database with specified name
- **Master User**: Database user with generated secure password
- **Read Replicas**: Optional read-only replicas for scaling read workloads
- **Backup Configuration**: Automated daily backups with point-in-time recovery
- **Network Security**: Private or public IP configuration with optional SSL enforcement

## Configuration Options

### Version Configuration

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `version` | string | `15` | PostgreSQL version (13, 14, 15) |
| `database_name` | string | `app_db` | Name of the default database to create |

### Sizing & Performance

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `tier` | string | `db-custom-2-7680` | Cloud SQL instance tier |
| `disk_size` | number | `100` | Initial disk size in GB (10-30720) |
| `read_replica_count` | number | `0` | Number of read replicas (0-5) |

#### Supported Instance Tiers

PostgreSQL on GCP Cloud SQL supports only **shared-core** or **custom machine types**:

| Tier | vCPUs | Memory | Use Case |
|------|-------|--------|----------|
| `db-f1-micro` | Shared | 0.6 GB | Dev/test only (not SLA covered) |
| `db-g1-small` | Shared | 1.7 GB | Dev/test only (not SLA covered) |
| `db-custom-2-7680` | 2 | 7.5 GB | Small production |
| `db-custom-4-16384` | 4 | 16 GB | Medium production |
| `db-custom-8-32768` | 8 | 32 GB | Large production |
| `db-custom-16-65536` | 16 | 64 GB | High performance |

> **Note**: The `db-n1-standard-*` tiers are NOT supported for PostgreSQL. Use custom machine types for production workloads.

### Network Configuration

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `ipv4_enabled` | boolean | `false` | Enable public IP address for the instance |
| `require_ssl` | boolean | `true` | Require SSL for all connections |
| `authorized_networks` | map | `{}` | Map of authorized networks (when public IP enabled) |

#### Authorized Networks Example

```yaml
network_config:
  ipv4_enabled: true
  require_ssl: true
  authorized_networks:
    office:
      value: "203.0.113.0/24"
    vpn:
      value: "10.0.0.0/8"
```

### Restore Configuration

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `restore_from_backup` | boolean | `false` | Restore database from existing backup |
| `source_instance_id` | string | - | Source Cloud SQL instance ID for restore |
| `master_username` | string | `postgres` | Master username for restored database |
| `master_password` | string | - | Master password for restored database |

### Import Existing Resources

| Property | Type | Description |
|----------|------|-------------|
| `instance_id` | string | ID of existing Cloud SQL instance to import |
| `database_name` | string | Name of existing database to import |
| `user_name` | string | Name of existing database user to import |

## Security Considerations

This module implements security-first defaults:

### Network Security
- Database instances are deployed with **private IP addresses by default**, requiring VPC access for connectivity
- **SSL connections are enforced** by default (`require_ssl: true`)
- Public IP can be enabled when needed with `ipv4_enabled: true`
- When public IP is enabled, use `authorized_networks` to whitelist specific IP ranges

### Access Control
- Master user credentials are automatically generated with strong passwords (16 characters, special characters included)
- When restoring from backup, explicit credential management is required to maintain security boundaries

### Data Protection
- **Encryption at rest and in transit** is enabled by default
- All instances use **SSD storage** for performance and security
- **Point-in-time recovery** is configured with 7-day backup retention
- Automated daily backups at 03:00 UTC

### Resource Protection
- Resources can be destroyed when needed for testing and development purposes
- The module includes lifecycle rules to ignore disk size changes, allowing automatic storage scaling
- `disk_autoresize` is enabled with a limit of 2x the initial disk size

### Import Safety
- When importing existing CloudSQL resources, the module maintains existing security configurations
- Resources are brought under Terraform management without disruption
- Lifecycle ignore rules prevent drift on imported resources

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `gcp_provider` | `@facets/gcp_cloud_account` | Yes | GCP cloud account configuration and credentials |
| `network` | `@facets/gcp-network-details` | Yes | GCP VPC network configuration for database placement |

## Outputs

| Name | Type | Description |
|------|------|-------------|
| `default` | `@facets/postgres` | PostgreSQL connection details (writer and reader endpoints) |

### Output Interfaces

#### Writer Interface
- `host`: Primary instance IP address
- `port`: PostgreSQL port (5432)
- `username`: Database username
- `password`: Database password (sensitive)
- `connection_string`: Full PostgreSQL connection string (sensitive)

#### Reader Interface
- `host`: Read replica IP address (or primary if no replicas)
- `port`: PostgreSQL port (5432)
- `username`: Database username
- `password`: Database password (sensitive)
- `connection_string`: Full PostgreSQL connection string (sensitive)

## Sample Configuration

```yaml
kind: postgres
flavor: gcp-cloudsql
version: '1.0'
disabled: false
spec:
  version_config:
    version: '15'
    database_name: app_db
  sizing:
    tier: db-custom-4-16384
    disk_size: 250
    read_replica_count: 1
  network_config:
    ipv4_enabled: false
    require_ssl: true
  restore_config:
    restore_from_backup: false
```

## Notes

- Read replicas are not created when importing existing instances
- Maintenance window is set to Sunday at 03:00 UTC with stable update track
- Database flags `log_checkpoints` and `log_connections` are enabled for auditing
- The module uses the private services connection from the network module for VPC peering
