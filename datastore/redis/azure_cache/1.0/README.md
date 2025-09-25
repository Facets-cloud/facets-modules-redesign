# Azure Cache for Redis Module v1.0

## Overview

This module provisions Azure Cache for Redis, a fully managed in-memory cache service built on open-source Redis. Premium SKU automatically includes daily backups with auto-created storage, VNet integration, and high availability features.

## Environment as Dimension

The module is environment-aware through:
- Resource naming includes environment unique identifier for isolation
- Cloud tags from environment applied to all resources
- Backup storage accounts are unique per environment with timestamp suffix

## Resources Created

- Azure Redis Cache instance (Basic, Standard, or Premium tier)
- Storage Account for backups (auto-created for Premium SKU only)
- Storage Container named "redis-backups" (auto-created for Premium SKU)
- Firewall rules for VNet subnet access (Premium SKU only)

## Network Integration

This module consumes network resources from an Azure network module:
- Automatically uses database subnet when available for better isolation
- Falls back to private subnet if database subnet is not configured
- Premium SKU deploys Redis within the VNet for enhanced security
- Firewall rules configured based on subnet selection

## Key Features

### Tiering
- **Basic/Standard**: Public access only, no VNet integration, no automatic backups
- **Premium**: Full VNet integration, automatic daily backups, high availability with replicas

### Automatic Backup Management (Premium SKU)
Premium SKU automatically:
- Creates a dedicated storage account for backups (no configuration needed)
- Enables daily RDB backups with 7-day retention
- Names storage account uniquely with timestamp suffix to avoid conflicts
- Manages backup lifecycle without user intervention

### Restore Capabilities (Optional)
To restore from an existing backup:
- Set `restore_from_backup` to true
- Provide `backup_file_name` (must end with .rdb)
- Backup file must be uploaded to the auto-created storage container

## Security Considerations

- TLS 1.2 minimum version enforced
- Non-SSL port disabled by default
- Premium tier provides full VNet isolation
- Access keys marked as sensitive in outputs
- Firewall rules restrict access to specific subnet CIDRs
- Backup storage uses encryption at rest

## Subnet Selection Logic

The module intelligently selects subnets:
1. **Database Subnet Priority**: Uses general database subnet if available
2. **Private Subnet Fallback**: Uses first private subnet otherwise
3. **Firewall Rules**: Automatically configured for selected subnet type