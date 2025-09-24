# Azure MySQL Flexible Server Module

**Version:** 1.0

## Overview

This module deploys Azure Database for MySQL - Flexible Server with high availability, automated backup, and optional read replicas. The module leverages network resources from the azure-network module, requiring MySQL-specific subnet and DNS zone configuration to be enabled.

## Prerequisites

The azure-network module must have MySQL Flexible Server support enabled:
```yaml
database_config:
  enable_mysql_flexible_subnet: true
```

## Environment as Dimension

This module is environment-aware with the following environment-specific behaviors:
- Server naming incorporates `environment.unique_name` for uniqueness across environments
- DNS zones and network configurations are environment-specific through the network module
- Tags from `environment.cloud_tags` are applied to all resources

## Resources Created

- Azure MySQL Flexible Server with configurable SKU and storage
- Initial database with specified charset and collation
- Random admin password generation (for new servers)
- Optional read replicas (up to 10)
- Firewall rule for Azure services access
- High availability configuration (Zone Redundant for non-burstable SKUs)

## Network Integration

This module consumes network resources from the azure-network module:
- Uses dedicated MySQL delegated subnet (`database_mysql_subnet_id`)
- Utilizes pre-configured MySQL Private DNS Zone (`mysql_dns_zone_id`)
- Requires VNet integration for private connectivity

## Security Considerations

- Administrator passwords are auto-generated using secure random generation
- Supports restore from backup with credential inheritance from source server
- Private endpoint connectivity through delegated subnet
- Optional firewall rule for Azure services (0.0.0.0)
- Backup retention configured with geo-redundant storage
- Sensitive outputs (passwords, connection strings) are marked as sensitive

## Advanced Features

- **Point-in-time restore**: Restore from existing backup with time specification
- **Read replicas**: Configure up to 10 read replicas for scaling read operations
- **Import support**: Import existing MySQL servers, databases, and firewall rules
- **High Availability**: Automatic Zone Redundant HA for General Purpose and Memory Optimized SKUs
- **Storage tiers**: Support for various storage performance tiers (P4 to P80)