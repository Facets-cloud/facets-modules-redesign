# Azure MySQL Flexible Server Module

[![Module Version](https://img.shields.io/badge/module-1.0-blue.svg)](./facets.yaml)
[![Cloud](https://img.shields.io/badge/cloud-azure-blue.svg)]()
[![Terraform](https://img.shields.io/badge/terraform-1.5.7-purple.svg)]()

## Overview

This module provisions an Azure Database for MySQL - Flexible Server with enterprise-grade security, high availability, and automated backup capabilities. It provides a developer-friendly abstraction for deploying production-ready MySQL databases on Azure with minimal configuration while maintaining security best practices.

The module supports point-in-time restore from existing databases, read replica scaling, and seamless integration with Azure Virtual Networks through private DNS zones.

## Environment as Dimension

This module is **environment-aware** and adapts its behavior based on the deployment environment:

- **Resource Naming**: Incorporates `var.environment.unique_name` to ensure globally unique resource names across environments
- **Tagging Strategy**: Applies `var.environment.cloud_tags` for consistent resource tagging and cost allocation
- **Network Integration**: Leverages environment-specific network configurations through input dependencies

The module uses `var.environment` extensively for resource naming patterns and applies standardized tagging from the platform, ensuring proper resource organization and tracking across development, staging, and production environments.

## Resources Created

- **Azure MySQL Flexible Server** - Primary database server with zone-redundant high availability
- **MySQL Database** - Initial database with configurable charset and collation
- **Private DNS Zone** - Secure network resolution for database connectivity  
- **DNS Zone Virtual Network Link** - Integration with Azure VNet infrastructure
- **Read Replica Servers** - Optional read-only replicas for scaling read workloads
- **Firewall Rules** - Azure service access configuration
- **Random Password** - Secure credential generation for database access

## Security Considerations

This module implements security-first defaults that cannot be disabled:

- **Network Isolation**: All database traffic uses private networking through VNet integration
- **Encryption**: Data encryption at rest and in transit is automatically enabled
- **High Availability**: Zone-redundant deployment prevents single-point-of-failure
- **Backup Security**: Geo-redundant backups with 7-day retention for disaster recovery
- **Access Control**: Private DNS zones restrict database access to authorized networks only
- **Credential Management**: Secure random password generation with configurable restore credentials

The module follows Azure security best practices and integrates with existing network security boundaries defined by the consuming infrastructure.
