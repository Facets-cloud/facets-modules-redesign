# Redis AWS ElastiCache Module

![Redis](https://img.shields.io/badge/redis-7.4-red?style=flat-square) ![AWS](https://img.shields.io/badge/AWS-ElastiCache-orange?style=flat-square) ![Version](https://img.shields.io/badge/version-1.0-blue?style=flat-square)

## Overview

This module provides a managed Redis cache using AWS ElastiCache with security and high availability defaults. It creates a fully-configured Redis replication group with encryption, authentication, and intelligent failover capabilities based on the number of nodes.

## Environment as Dimension

The module is environment-aware and will create unique resources per environment using the `var.environment.unique_name`. Different environments can have different configurations through the spec parameters, allowing for environment-specific sizing and settings.

## Resources Created

- **ElastiCache Replication Group**: Redis cluster with configurable node count and type
- **ElastiCache Subnet Group**: Network configuration for private subnet deployment  
- **Security Group**: VPC security group allowing Redis traffic from within the VPC
- **Random Password**: Secure authentication token for Redis connections

## High Availability Logic

The module intelligently configures high availability based on the number of cache nodes:

- **Single Node (1 node)**: Disables automatic failover and Multi-AZ for cost optimization
- **Multiple Nodes (2+ nodes)**: Enables automatic failover and Multi-AZ for high availability

This ensures compatibility with AWS ElastiCache requirements while providing flexibility for different use cases.

## Security Considerations

Security is built-in with hardcoded secure defaults:

- **Encryption at Rest**: Always enabled for data protection
- **Encryption in Transit**: Always enabled for secure connections
- **Authentication**: Random 64-character auth token generated automatically
- **Network Isolation**: Deployed in private subnets with VPC-only access
- **Automatic Failover**: Enabled when using 2+ nodes for production resilience
- **Backup Protection**: Automatic snapshots with configurable retention (7 days default)

The module follows security best practices and does not expose sensitive configuration options that could compromise security.

## Module Configuration

### Version & Basic Configuration
- **Redis Version**: Support for Redis 7.0, 7.2, and 7.4 (defaults to 7.4)
- **Node Type**: Configurable ElastiCache node types from t3.micro to m6g.xlarge

### Sizing & Performance  
- **Cache Nodes**: 1-6 nodes supported (defaults to 2 for high availability)
- **Parameter Groups**: Configurable Redis parameter groups
- **Snapshot Retention**: 0-35 days backup retention

### Restore Operations
- **Backup Restore**: Restore cluster from existing snapshots
- **Snapshot ARN**: Specify source snapshot for restoration

### Import Support
Import existing ElastiCache resources including clusters, subnet groups, and security groups for migration scenarios.

## Dependencies

Requires AWS provider configuration and VPC details from other Facets modules. The module automatically configures networking and security within the provided VPC infrastructure.

## Output Interface

Provides standardized Redis connectivity through the `@facets/redis-elasticache` output type, including connection strings, endpoints, and authentication tokens for application integration.