# MySQL AWS RDS Database Module

[![Facets](https://img.shields.io/badge/facets-module-blue)](https://facets.cloud)
[![Version](https://img.shields.io/badge/version-1.0-green)](./facets.yaml)

## Overview

This module provisions a managed MySQL database instance on AWS RDS with enterprise-grade security, high availability, and automated backup capabilities. It provides a developer-friendly interface for creating production-ready MySQL databases with configurable performance tiers and optional read replicas.

## Environment as Dimension

This module is environment-aware and automatically configures resources based on the deployment environment. Resource naming, tagging, and network configurations adapt to the specific environment context through the `var.environment` parameter. Storage autoscaling, backup retention, and maintenance windows are configured with production-ready defaults that remain consistent across environments.

## Resources Created

The module creates the following AWS resources:

- **RDS MySQL Instance** - Primary database instance with configurable version, storage, and performance settings
- **Read Replicas** - Optional read-only database replicas for improved read performance and availability
- **DB Subnet Group** - Network configuration for database placement within private subnets
- **Security Group** - Network access controls restricting database access to VPC CIDR range
- **Secrets Manager Secret** - Secure storage for database master password
- **CloudWatch Log Groups** - Automatic log collection for error, general, and slow query logs

## Security Considerations

This module implements security best practices by default:

- **Encryption at Rest** - All database storage is encrypted using AWS KMS
- **Network Isolation** - Database instances are deployed in private subnets with no public access
- **Access Control** - Security groups restrict access to VPC CIDR range only
- **Credential Management** - Master passwords are generated automatically and stored in AWS Secrets Manager
- **Multi-AZ Deployment** - High availability is enabled by default for production resilience
- **Automated Backups** - 7-day backup retention with point-in-time recovery capabilities
- **Performance Monitoring** - Performance Insights enabled for database optimization (when supported)

The module supports importing existing RDS instances, subnet groups, and security groups to bring existing infrastructure under management without recreation. Restore functionality allows creating new instances from existing backups while maintaining security configurations.

## Key Features

**Version Management** - Supports MySQL versions 5.7, 8.0, and 8.4 with automatic validation

**Storage Options** - Configurable storage types (gp2, gp3, io1, io2) with automatic scaling support

**Performance Scaling** - Multiple instance classes from development (db.t3.micro) to production (db.m5.2xlarge)

**Read Scalability** - Support for up to 5 read replicas with automatic endpoint management

**Backup and Recovery** - Automated daily backups with point-in-time recovery and restore functionality

**Resource Import** - Import existing RDS instances, subnet groups, and security groups without disruption

**Instance Class Optimization** - Automatic Performance Insights configuration based on instance capabilities