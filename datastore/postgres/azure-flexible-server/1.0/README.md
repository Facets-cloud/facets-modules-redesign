# PostgreSQL Azure Flexible Server

[![Terraform](https://img.shields.io/badge/terraform-~%3E%201.5-blue)](https://www.terraform.io/)
[![Azure](https://img.shields.io/badge/provider-azurerm-blue)](https://registry.terraform.io/providers/hashicorp/azurerm/latest)

## Overview

This module provisions an Azure PostgreSQL Flexible Server with secure defaults and restore capabilities. It provides a developer-friendly abstraction for managing PostgreSQL databases on Azure without requiring deep cloud infrastructure knowledge.

The module is designed for development teams needing a managed PostgreSQL database in Azure with high availability, automated backups, and optional read replicas.

## Environment as Dimension

This module is environment-aware and uses `var.environment.unique_name` for resource naming and `var.environment.cloud_tags` for consistent tagging across environments. Different environments will have separate PostgreSQL servers with environment-specific names and configurations.

## Resources Created

The module creates the following Azure resources:

- **PostgreSQL Flexible Server** - Primary database server with configurable performance tier
- **Private DNS Zone** - Custom DNS zone for private network access
- **DNS Zone Virtual Network Link** - Links the DNS zone to the specified VNet
- **Dedicated Subnet** - Subnet delegated specifically for PostgreSQL Flexible Server
- **PostgreSQL Database** - Default "postgres" database within the server
- **Read Replicas** - Optional read-only replicas for scaling read operations
- **Security Configurations** - Logging and connection throttling settings
- **Random Password Generator** - Secure password generation for database access

## Security Considerations

The module implements security best practices by default:

- **Private Network Access Only**: Server is deployed in a private subnet with no public internet access
- **SSL Enforcement**: All connections require SSL/TLS encryption
- **Automated Backups**: 7-day retention with geo-redundant storage
- **High Availability**: Zone-redundant deployment for GeneralPurpose and MemoryOptimized tiers
- **Access Logging**: Connection and disconnection events are logged for auditing
- **Connection Throttling**: Protection against brute force attacks
- **Network Security**: Access restricted to VNet subnets only

All sensitive data like passwords are managed securely through Terraform state and can be integrated with Azure Key Vault for additional security layers.