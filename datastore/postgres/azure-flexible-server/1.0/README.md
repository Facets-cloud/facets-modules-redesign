# PostgreSQL Azure Flexible Server

[![Terraform](https://img.shields.io/badge/terraform-~%3E%201.5-blue)](https://www.terraform.io/)
[![Azure](https://img.shields.io/badge/provider-azurerm-blue)](https://registry.terraform.io/providers/hashicorp/azurerm/latest)

## Overview

This module provisions an Azure PostgreSQL Flexible Server with secure defaults, restore capabilities, and intelligent DNS zone sharing for multi-server environments. It provides a developer-friendly abstraction for managing PostgreSQL databases on Azure with enterprise-grade features like conflict-free CIDR allocation and shared private DNS resolution.

The module is designed for development teams needing managed PostgreSQL databases with high availability, automated backups, read replicas, and seamless integration across multiple database instances in the same environment.

## Key Features

### 🚀 **Multi-Instance CIDR Allocation**
- **Conflict-Free Deployment**: Supports unlimited concurrent PostgreSQL deployments in the same VNet
- **Deterministic Subnet Assignment**: Same instance name always gets the same subnet (idempotent)
- **High-Range Strategy**: Uses subnet numbers 924-1023 to avoid typical user subnet conflicts (0-100)
- **Comprehensive Conflict Detection**: Scans all existing subnets to prevent overlaps

### 🌐 **Smart DNS Zone Sharing**
- **Environment-Level DNS Zones**: Single private DNS zone per environment instead of per server
- **Cost Optimization**: Reduces Azure DNS zone costs for multi-server deployments
- **Flexible Management**: First server creates DNS zone, subsequent servers reuse it
- **Simplified Operations**: All PostgreSQL servers share consistent private DNS resolution

### 🔄 **Restore & Backup Capabilities**
- **Point-in-Time Recovery**: Restore from any backup within retention period
- **Automated Lifecycle Management**: Proper handling of restore scenarios
- **Database Migration**: Skip database recreation during restore operations
- **Password Handling**: Smart password management for restored servers

### 📈 **Performance & Scaling**
- **Read Replicas**: Support for 0-5 read replicas for horizontal scaling
- **Flexible SKUs**: Burstable, GeneralPurpose, and MemoryOptimized tiers
- **Storage Scaling**: 32GB to 16TB with automatic growth capabilities
- **Performance Tiers**: Configurable compute and storage based on workload needs

## Environment as Dimension

This module is environment-aware and creates shared infrastructure at the environment level:

- **DNS Zone Sharing**: `pg-dns-${environment.unique_name}.postgres.database.azure.com` shared across all PostgreSQL servers
- **Environment Tagging**: Uses `var.environment.cloud_tags` for consistent resource tagging
- **Unique Naming**: Resource names include `var.environment.unique_name` for environment isolation
- **Network Integration**: Integrates with environment-level VNet and networking configurations

## DNS Zone Configuration

### **Create DNS Zone (Default)**
For the **first PostgreSQL server** in an environment:
```yaml
postgres-primary:
  intent: postgres
  flavor: azure-flexible-server
  spec:
    network_config:
      create_dns_zone: true  # Default - creates new DNS zone
    # ... other configuration
```

### **Reuse Existing DNS Zone**
For **additional PostgreSQL servers** in the same environment:
```yaml
postgres-secondary:
  intent: postgres
  flavor: azure-flexible-server
  spec:
    network_config:
      create_dns_zone: false  # Uses existing DNS zone
    # ... other configuration
```

### **DNS Zone Naming Pattern**
All servers in the same environment share:
- **DNS Zone Name**: `pg-dns-${environment.unique_name}.postgres.database.azure.com`
- **Private Resolution**: All PostgreSQL servers resolve through the same DNS zone
- **VNet Integration**: DNS zone automatically linked to environment VNet

### **Multi-Server Deployment Strategy**
1. **Deploy First Server**: `create_dns_zone: true` → Creates shared DNS infrastructure
2. **Deploy Additional Servers**: `create_dns_zone: false` → Uses existing DNS infrastructure
3. **Shared Networking**: All servers share private DNS resolution and VNet connectivity
4. **Independent Subnets**: Each server gets its own /28 delegated subnet for isolation

## Resources Created

### **Network Infrastructure**
- **Dedicated Subnet** (/28) - Delegated specifically for PostgreSQL Flexible Server
- **Private DNS Zone** - Shared DNS zone for environment (conditional creation)
- **DNS Zone VNet Link** - Links DNS zone to VNet (conditional creation)

### **PostgreSQL Infrastructure**
- **PostgreSQL Flexible Server** - Primary database server with configurable performance
- **PostgreSQL Database** - Default database within the server (conditional creation)
- **Read Replicas** - Optional read-only replicas for horizontal scaling (0-5)
- **Security Configurations** - Connection logging and audit settings

### **Security & Access**
- **Random Password Generator** - Secure admin password creation
- **Private Network Access** - VNet-only connectivity with no public access
- **SSL/TLS Encryption** - Enforced encrypted connections

## Security Considerations

The module implements enterprise security best practices:

### **Network Security**
- **Private-Only Access**: No public internet connectivity, VNet integration only
- **Dedicated Subnets**: Each server gets isolated /28 subnet with PostgreSQL delegation
- **DNS Resolution**: Private DNS zones for internal name resolution
- **Service Endpoints**: Azure Storage endpoints for secure backup operations

### **Data Protection**
- **Encryption at Rest**: Azure-managed encryption for all data storage
- **SSL/TLS Enforcement**: All database connections require encryption
- **Automated Backups**: 7-day retention with point-in-time recovery capability
- **Geo-Redundancy**: Optional geo-redundant backup storage for disaster recovery

### **Access Control & Auditing**
- **Connection Logging**: All database connections logged for security auditing
- **Disconnect Logging**: Connection termination events tracked
- **Admin Password Management**: Secure random password generation
- **Restore Password Handling**: Proper credential management for restored servers

### **Operational Security**
- **Lifecycle Management**: Prevents accidental resource destruction
- **Configuration Drift Protection**: Ignores Azure-managed configuration changes
- **Resource Tagging**: Consistent tagging for compliance and cost allocation

The module ensures PostgreSQL deployments meet enterprise security requirements while providing developers with a simple, secure interface for database provisioning and management.