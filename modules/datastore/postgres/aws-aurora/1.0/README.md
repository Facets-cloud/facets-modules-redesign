# PostgreSQL Aurora Cluster

A managed PostgreSQL Aurora cluster with high availability, automated backups, and read replicas.

## Overview

This module provisions an AWS Aurora PostgreSQL cluster with serverless v2 scaling capabilities. It provides a fully managed relational database service with automated backup, manual snapshot restore, and multi-AZ deployment for high availability.

## Environment as Dimension

This module is environment-aware and adapts configuration based on the deployment environment:

- **Cluster identifiers** include environment unique names to prevent conflicts across environments
- **Resource tags** automatically include environment-specific cloud tags for proper governance
- **Security groups** and subnet groups are scoped to the specific environment's VPC
- **Backup and maintenance windows** remain consistent across environments for operational predictability

## Resources Created

The module creates the following AWS resources:

- **Aurora PostgreSQL Cluster** - Main database cluster with configurable engine version
- **Aurora Cluster Instances** - Writer instance and configurable number of read replicas
- **DB Subnet Group** - Database subnet group using provided VPC private subnets
- **Security Group** - VPC security group allowing PostgreSQL traffic (port 5432) within VPC CIDR
- **Random Password** - Auto-generated secure password when not restoring from backup

## Security Considerations

This module implements several security best practices:

- **Encryption at rest** is always enabled for the Aurora cluster
- **Encryption in transit** is enforced for all database connections
- **Master password** is auto-generated and stored securely in Terraform state
- **Network isolation** restricts database access to VPC CIDR blocks only
- **Backup retention** is set to 7 days with manual snapshot restore capability
- **Performance Insights** is enabled for database monitoring and troubleshooting

⚠️ **Snapshot Restoration Note**: When restoring from a manual snapshot, the module automatically inherits the engine version, database name, and master credentials from the original snapshot. The specified `engine_version` and `database_name` in the configuration are ignored during restoration, and the `master_username`/`master_password` from `restore_config` are used to access the restored cluster.

The module supports importing existing Aurora resources and restoring from manual snapshots while maintaining security standards.

## Supported PostgreSQL Versions

This module supports the following Aurora PostgreSQL versions:

- **PostgreSQL 13.21** - Stable, end of support approaching
- **PostgreSQL 14.18** - Stable and widely used
- **PostgreSQL 15.13** - Stable with improved performance
- **PostgreSQL 16.9** - Recommended for new deployments (default)
- **PostgreSQL 17.5** - Latest version with newest features

## Instance Classes

Supported instance classes for Aurora PostgreSQL:

- **db.t4g.medium** - Burstable, cost-effective for development and testing
- **db.r5.large** - General purpose for production workloads
- **db.r5.xlarge** - Higher performance for demanding workloads
- **db.r5.2xlarge** - High performance for large-scale applications
- **db.r6g.large** - Graviton2-based, improved price-performance
- **db.r6g.xlarge** - Graviton2-based, higher performance

## Key Features

### Serverless v2 Scaling
- Configure minimum and maximum Aurora Capacity Units (ACU)
- Automatic scaling based on workload demands
- Cost-effective for variable workloads

### High Availability
- Multi-AZ deployment with automatic failover
- Configurable read replicas (0-15) for read scaling
- Separate reader and writer endpoints

### Backup and Recovery
- Automated daily backups with 7-day retention
- Manual snapshot support
- Point-in-time recovery capability
- Restore from snapshot functionality

### Import Existing Resources
- Import existing Aurora clusters
- Import writer and reader instances
- Preserve existing configurations
