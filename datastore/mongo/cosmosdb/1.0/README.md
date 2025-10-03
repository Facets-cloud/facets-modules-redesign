# Azure Cosmos DB for MongoDB Module

## Overview
This module deploys Azure Cosmos DB with MongoDB API, providing a fully managed NoSQL database service. It supports importing existing resources, point-in-time restore from backups, and flexible throughput configurations.

## Environment as Dimension
The module is environment-aware through:
- Unique naming using `var.environment.unique_name` for resource identification
- Environment-specific cloud tags applied to all resources
- Resource group and region configuration inherited from network module

## Resources Created
- Azure Cosmos DB Account with MongoDB API
- MongoDB Database with configurable throughput
- Optional continuous backup for point-in-time restore capability
- Support for multi-region replication
- Automatic failover configuration

## Key Features

### Import Functionality
- Import existing Cosmos DB accounts without recreation
- Import existing MongoDB databases
- Seamless integration with existing infrastructure

### Backup and Restore
- **Periodic Backup**: Default 4-hour intervals with 7-day retention
- **Continuous Backup**: Optional 30-day point-in-time restore capability
- **Restore Operations**: Create new accounts from existing backups with timestamp precision

### Performance Configuration
- Provisioned or serverless throughput modes
- Autoscale support from 400 to 1,000,000 RU/s
- Multi-region write support for global distribution

## Security Considerations
- Connection strings use SSL/TLS encryption by default
- Primary and secondary keys for authentication
- Public network access configurable (currently enabled for testing)
- Prevent destroy lifecycle rules to protect against accidental deletion

## Usage Notes

### For Import Operations
Provide the existing resource names in the imports configuration. The module will reference existing resources without modifying them.

### For Restore Operations
1. Source account must have continuous backup enabled
2. Restore creates a NEW Cosmos DB account (not in-place restore)
3. Provide source account name and RFC3339 timestamp
4. Restored account will be in the same region as source

### Network Integration
The module consumes network details from the azure_network module:
- Uses provided resource group for all resources
- Deploys in specified Azure region
- Does not create network resources itself

## Limitations
- Restore operations require continuous backup on source account
- Point-in-time restore window limited to 30 days
- Multi-region secondary location currently hardcoded to East US
- No private endpoint support (uses public endpoints with authentication)