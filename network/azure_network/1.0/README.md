# Azure Network Module

## Overview

Creates a comprehensive Azure Virtual Network with automatically calculated subnet sizes, including dedicated database subnets with proper delegation for PostgreSQL and MySQL Flexible Servers. This module provides a complete networking foundation for Azure infrastructure with built-in support for database services following Facets platform best practices.

## Environment Awareness

This module is environment-aware through the `var.environment` variable, which affects:
- Resource naming conventions using `environment.unique_name`
- Resource tagging with `environment.cloud_tags`  
- DNS zone names for database services include environment unique name

## Resources Created

### Core Networking
- Azure Resource Group (with prevent_destroy lifecycle)
- Virtual Network (VNet) with /16 CIDR block (with prevent_destroy lifecycle)
- Public subnets (/24) - one per availability zone
- Private subnets (/18) - one per availability zone  
- NAT Gateway(s) with public IP addresses
- Route tables for subnet routing
- Network Security Groups with default rules

### Database Networking (Optional)
- General database subnet (/24) - for private endpoints and non-delegated resources
- PostgreSQL delegated subnet (/24) - exclusively for PostgreSQL Flexible Servers
- MySQL delegated subnet (/24) - exclusively for MySQL Flexible Servers
- PostgreSQL Private DNS Zone with VNet link (with prevent_destroy lifecycle)
- MySQL Private DNS Zone with VNet link (with prevent_destroy lifecycle)
- Database-specific Network Security Groups with comprehensive rules

## Key Features

### Subnet Delegation
The module creates dedicated delegated subnets for database services:
- **PostgreSQL subnet**: Delegated to `Microsoft.DBforPostgreSQL/flexibleServers`
- **MySQL subnet**: Delegated to `Microsoft.DBforMySQL/flexibleServers`
- These subnets can host multiple instances of their respective database types
- Each /24 subnet supports approximately 60 database instances with HA enabled

### Private Endpoint Support
- General database subnet configured for private endpoints
- Private endpoint network policies properly configured
- Supports Azure Cache for Redis, CosmosDB, Storage, Key Vault, and more

### Automatic IP Allocation
- Public subnets: /24 blocks (256 IPs each)
- Private subnets: /18 blocks (16,384 IPs each)
- Database subnets: /24 blocks (256 IPs each)
- Default allocation starts at x.x.100.0/24 for database subnets to avoid conflicts

### DNS Zone Management
- Creates private DNS zones for database services at the network level
- Zones are shared across all database instances in the VNet
- Automatic VNet linking for DNS resolution
- DNS zones follow Azure naming requirements (*.postgres.database.azure.com, *.mysql.database.azure.com)

### Network Security
- Comprehensive NSG rules for database subnets:
  - PostgreSQL port 5432 from VirtualNetwork
  - MySQL port 3306 from VirtualNetwork
  - Azure Storage for backups
  - Azure Active Directory for authentication
  - Azure Monitor for metrics and logging
  - Internal database communication for HA and replication
- Service endpoints configured for optimal performance

## Database Subnet Configuration

When `database_config.enable_database_subnets` is enabled:
1. Three /24 subnets are created for database services
2. PostgreSQL and MySQL subnets receive proper delegation
3. Private DNS zones are created for each database type
4. All database resources can share these network resources

### IP Usage per Database Type
- **PostgreSQL Flexible Server**: 4 IPs with HA, 1 IP without HA
- **MySQL Flexible Server**: 4 IPs with HA, 1 IP without HA
- **General Database Resources**: Variable based on service type (1 IP per private endpoint)

## Security Considerations

- Database subnets are protected with dedicated Network Security Groups
- Only VNet-internal traffic is allowed to database ports
- Storage, Azure AD, and Azure Monitor service tags properly configured
- No public IP addresses assigned to database subnets
- Private DNS zones ensure internal name resolution only
- Private endpoint network policies enabled for general database subnet
- Prevent destroy lifecycle on critical resources (VNet, Resource Group, DNS Zones)

## Routing Configuration

- Public subnets use standard route tables
- Private subnets route through NAT Gateway for internet access
- General database subnet uses private subnet route table for consistency
- Delegated subnets (PostgreSQL/MySQL) manage their own routing automatically

## Troubleshooting Guide

### Common Issues and Solutions

1. **Subnet CIDR Conflicts**
   - **Issue**: Custom database subnet CIDRs overlap with existing subnets
   - **Solution**: Use default allocation (x.x.100.0/24, x.x.101.0/24, x.x.102.0/24) or ensure no overlap

2. **DNS Resolution Failures**
   - **Issue**: Database cannot resolve private DNS names
   - **Solution**: Verify DNS zones are created and VNet links are active

3. **Database Connection Timeouts**
   - **Issue**: Cannot connect to database from application
   - **Solution**: Check NSG rules allow traffic from source subnet on correct ports

4. **Private Endpoint Creation Fails**
   - **Issue**: Cannot create private endpoint in subnet
   - **Solution**: Verify using general database subnet (not delegated ones)

5. **Database Subnet Full**
   - **Issue**: Cannot create new database instance
   - **Solution**: Each /24 subnet supports ~60 HA instances; consider cleanup or expansion

## Migration Guide

### Migrating from Standalone Database Modules

#### Before Migration (Database module creates its own subnet):
```hcl
# Old approach - database module creates subnet
resource "azurerm_subnet" "postgres" {
  # Subnet created by database module
}
```

#### After Migration (Database module uses network outputs):
```hcl
# New approach - consume from network module
locals {
  postgres_subnet_id   = var.inputs.network_details.attributes.database_postgresql_subnet_id
  postgres_dns_zone_id = var.inputs.network_details.attributes.postgresql_dns_zone_id
}
```

### Migration Steps:
1. Deploy updated network module with database configuration enabled
2. Note the new subnet and DNS zone IDs from outputs
3. Update database modules to consume network outputs
4. Migrate databases to new subnets (may require recreation)
5. Remove old subnets and DNS zones

## Service Compatibility Matrix

| Service | Subnet to Use | Requirements |
|---------|---------------|--------------|
| PostgreSQL Flexible Server | `database_postgresql_subnet` | Delegation required |
| MySQL Flexible Server | `database_mysql_subnet` | Delegation required |
| Azure Cache for Redis | `database_general_subnet` | Private endpoint |
| CosmosDB | `database_general_subnet` | Private endpoint |
| Storage Account | `database_general_subnet` | Private endpoint |
| Azure SQL Database | `database_general_subnet` | Private endpoint |
| Key Vault | `database_general_subnet` | Private endpoint |
| Service Bus | `database_general_subnet` | Private endpoint |
| Event Hub | `database_general_subnet` | Private endpoint |

## Outputs

The module exposes comprehensive networking details through the `@facets/azure-network-details` output type:
- VNet and subnet IDs
- Database subnet details (IDs, names, CIDRs)
- DNS zone information (IDs, names)
- Resource group information
- All subnet CIDR blocks
- NAT Gateway and public IP information

Database modules can consume these outputs directly without managing network resources.

## Best Practices

1. **Always use default database subnet CIDRs** unless you have specific requirements
2. **Enable database subnets even if not immediately needed** - easier to have them ready
3. **Monitor subnet IP usage** - plan for growth before hitting limits
4. **Use tags consistently** - leverage environment.cloud_tags
5. **Never modify delegated subnets manually** - let Terraform manage them
6. **Test DNS resolution** after deployment to ensure proper configuration
7. **Review NSG rules regularly** - ensure they meet security requirements

## Facets Platform Integration

This module is optimized for the Facets platform:
- Follows Facets naming conventions (`instance_name`, `environment.unique_name`)
- Uses Facets-injected variables properly
- Implements prevent_destroy on critical resources
- Provides comprehensive outputs for module composition
- Supports environment-specific overrides
- Compatible with Facets blueprint designer

## Performance Optimization

- Service endpoints reduce latency for Azure services
- Delegated subnets optimize database performance
- NAT Gateway provides reliable outbound connectivity
- Route tables minimize unnecessary hops
- NSG rules are optimized for minimal overhead