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
- **Basic/Standard**: Public access only, no VNet integration, no automatic backups, no import/export capability
- **Premium**: Full VNet integration, automatic daily backups, high availability with replicas, import/export support

### Automatic Backup Management (Premium SKU)
Premium SKU automatically:
- Creates a dedicated storage account for backups (no configuration needed)
- Enables daily RDB backups with 7-day retention
- Names storage account uniquely with timestamp suffix to avoid conflicts
- Manages backup lifecycle without user intervention

## Data Import/Restore Process (Premium SKU Only)

**IMPORTANT**: Azure Redis Cache does NOT support automatic restore from RDB files during Terraform creation, unlike MySQL/PostgreSQL Flexible Servers. Data import is a manual post-deployment process.

### Prerequisites
- Premium tier Redis Cache (Basic/Standard tiers do NOT support import/export)
- RDB backup file from any Redis server (including other Azure Redis instances)
- Access to Azure Portal or Azure CLI

### Import Steps
1. **Deploy the Redis Cache** using this Terraform module
2. **Upload your RDB file** to the auto-created storage container:
   - Storage Account: Created automatically with pattern `{cache-name}bk{timestamp}`
   - Container Name: `redis-backups`
3. **Navigate to Azure Portal**:
   - Go to your Redis Cache instance
   - Select "Administration" > "Import Data" from left menu
   - Choose your RDB file from the storage container
   - Click "Import" to start the restore process
4. **Monitor import progress** in Azure Portal notifications

### Important Notes
- Import/Export is ONLY available for Premium tier
- Import process deletes all existing data in the cache
- Cache is unavailable to clients during import
- Import creates data from the RDB file, not a point-in-time restore
- This is fundamentally different from database restore operations

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

## Terraform State Import

To import an existing Azure Redis Cache into Terraform state (NOT data import):
```bash
terraform import azurerm_redis_cache.main /subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.Cache/redis/{cache-name}
```
Note: This imports the resource configuration only, not the cached data.