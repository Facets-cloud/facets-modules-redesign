# MongoDB with Azure Cosmos DB Module

A Terraform module that provisions a MongoDB-compatible database using Azure Cosmos DB. This module provides a secure, scalable, and managed MongoDB service with automatic failover and backup capabilities as a new flavor under the existing mongo intent.

## Overview

This module creates an Azure Cosmos DB account configured for MongoDB API with automatic scaling, multi-region support, and enterprise-grade security features. It abstracts the complexity of Cosmos DB configuration while providing essential MongoDB functionality for applications.

## Environment as Dimension

This module is environment-aware and uses `var.environment` for:
- Unique resource naming per environment using `environment.unique_name`
- Environment-specific tags through `environment.cloud_tags`
- Environment isolation for imported resources and restore operations

Different environments will have separate Cosmos DB accounts with isolated data and configurations.

## Resources Created

- **Azure Cosmos DB Account** - MongoDB-compatible database service with configured API version and consistency settings
- **MongoDB Database** - Primary database within the Cosmos DB account with autoscale throughput
- **Backup Configuration** - Automated periodic backups with 7-day retention
- **Security Settings** - Private network access and virtual network filtering enabled by default
- **High Availability** - Automatic failover and optional multi-region write capabilities

## Security Considerations

This module implements security-first defaults:

- **Private Network Access** - Public network access is disabled by default
- **Virtual Network Filtering** - Network isolation through VNet integration
- **Encryption at Rest** - All data encrypted using Azure-managed keys
- **Connection Security** - Secure connection strings with authentication
- **Backup Encryption** - Backup data is encrypted with the same keys as primary data
- **Access Control** - Connection requires valid credentials (account keys)

The module generates secure connection strings and access keys that should be stored securely in your application configuration or key management service.
