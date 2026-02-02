# Azure Managed Redis Module v1.0

## Overview

This module provisions Azure Managed Redis, Microsoft's next-generation Redis service built on Redis 7.4+. It provides enhanced performance, enterprise security features, and automatic high availability. All connections are secured via Private Endpoint for VNet-only access.

## Environment as Dimension

The module is environment-aware through:
- Resource naming includes environment unique identifier for isolation
- Cloud tags from environment applied to all resources
- Private DNS zone and endpoint are unique per environment

## Resources Created

- Azure Managed Redis instance (Balanced tier SKUs)
- Private Endpoint for secure VNet access
- Private DNS Zone (`privatelink.redisenterprise.cache.azure.net`)
- Private DNS Zone VNet Link
- Private DNS A Record for endpoint resolution

## Network Integration

This module consumes network resources from an Azure network module:
- Automatically uses database subnet when available for better isolation
- Falls back to private subnet if database subnet is not configured
- Public network access is disabled by default
- All traffic flows through Private Endpoint within the VNet

## Key Features

### Size Options

| Size | SKU | Memory | Use Case |
|------|-----|--------|----------|
| small | Balanced_B1 | ~1GB | Development/Testing |
| medium | Balanced_B5 | ~6GB | Small production workloads |
| large | Balanced_B50 | ~30GB | High-traffic applications |
| xlarge | Balanced_B100 | ~60GB | Enterprise workloads |

### Clustering Modes

- **standard** (OSS Cluster): Recommended for new applications, uses native Redis clustering
- **legacy_compatible** (Enterprise Cluster): For migration from older Redis deployments

### Security Features

- TLS encryption enforced (Encrypted client protocol)
- Public network access disabled
- Private Endpoint for VNet-only connectivity
- Optional password authentication (enabled by default)
- Private DNS resolution within VNet

## Differences from Azure Cache for Redis

Azure Managed Redis is the next-generation offering with key differences:

| Feature | Azure Managed Redis | Azure Cache for Redis |
|---------|--------------------|-----------------------|
| Redis Version | 7.4+ | Up to 6.x |
| Port | 10000 | 6380 (TLS) |
| SKU Types | Balanced, Memory Optimized, Compute Optimized | Basic, Standard, Premium |
| Network | Private Endpoint only | VNet injection or Public |
| Availability | Built-in HA | Depends on tier |

## Security Considerations

- All connections use TLS encryption
- Public network access is disabled
- Access limited to VNet through Private Endpoint
- Access keys marked as sensitive in outputs
- Private DNS ensures hostname resolution stays within VNet

## Subnet Selection Logic

The module intelligently selects subnets:
1. **Database Subnet Priority**: Uses general database subnet if available
2. **Private Subnet Fallback**: Uses first private subnet otherwise
3. **Private Endpoint**: Deployed in selected subnet for secure access

## Connection Details

Applications connect using:
- **Host**: `{cache-name}.privatelink.redisenterprise.cache.azure.net`
- **Port**: `10000`
- **Protocol**: `rediss://` (TLS-encrypted)

## Terraform State Import

To import existing Azure Managed Redis resources into Terraform state:

```bash
# Import the Redis instance
terraform import azurerm_managed_redis.main /subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.Cache/redisenterprise/{cache-name}

# Import the Private Endpoint
terraform import azurerm_private_endpoint.redis /subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.Network/privateEndpoints/{endpoint-name}
```

Note: This imports resource configuration only, not the cached data.
