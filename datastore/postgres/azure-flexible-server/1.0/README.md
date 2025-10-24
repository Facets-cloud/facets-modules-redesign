# PostgreSQL Azure Flexible Server Module v1.0

## Overview

This module deploys a PostgreSQL Flexible Server on Azure with secure defaults, private networking, and optional read replicas. It consumes network resources from the Azure Network module, including pre-configured delegated subnets and DNS zones.

## Environment as Dimension

The module uses `var.environment.unique_name` for resource naming and tagging. Each environment will have its own PostgreSQL server instance with environment-specific configuration.

## Resources Created

- Azure PostgreSQL Flexible Server (primary instance)
- PostgreSQL database (default database)
- Read replica servers (optional, up to 5)
- Random password for admin user
- Security configurations (logging enabled)

## Prerequisites

This module requires the Azure Network module to be configured with PostgreSQL support:

```yaml
database_config:
  enable_postgresql_flexible_subnet: true
```

The network module will provide:
- Delegated /24 subnet for PostgreSQL Flexible Servers
- Private DNS zone for PostgreSQL
- DNS zone VNet link

## Security Considerations

- Public network access is disabled by default
- All traffic flows through private VNet integration
- Admin password is randomly generated
- Connection and disconnection logging enabled
- SSL enforcement is enabled
- Passwords are marked as sensitive in outputs

## Configuration Options

### Version Configuration
- PostgreSQL versions: 13, 14, 15 (default: 15)
- Performance tiers: Burstable, GeneralPurpose, MemoryOptimized

### Sizing Options
- Storage: 32 GB to 16,384 GB
- SKU options from B_Standard_B1ms to MO_Standard_E4s_v3
- Read replicas: 0 to 5

### Advanced Features
- Point-in-time restore from existing backup
- Import existing PostgreSQL Flexible Server
- Configurable backup retention (default: 7 days)

## Network Integration

The module consumes network resources from the Azure Network module:
- Uses pre-created delegated subnet for PostgreSQL
- Uses pre-configured DNS zone
- Ensures proper VNet isolation

## Outputs

The module provides:
- Server connection details (reader and writer interfaces)
- Server metadata (FQDN, version, storage)
- Network configuration details
- Backup and HA settings
