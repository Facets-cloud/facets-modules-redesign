# MySQL Aurora Cluster

A managed MySQL Aurora cluster with high availability, automated backups, and read replicas.

## Overview

This module provisions an AWS Aurora MySQL cluster with serverless v2 scaling capabilities. It provides a fully managed relational database service with automated backup, manual snapshot restore, and multi-AZ deployment for high availability.

## Environment as Dimension

This module is environment-aware and adapts configuration based on the deployment environment:

- **Cluster identifiers** include environment unique names to prevent conflicts across environments
- **Resource tags** automatically include environment-specific cloud tags for proper governance
- **Security groups** and subnet groups are scoped to the specific environment's VPC
- **Backup and maintenance windows** remain consistent across environments for operational predictability

## Resources Created

The module creates the following AWS resources:

- **Aurora MySQL Cluster** - Main database cluster with configurable engine version
- **Aurora Cluster Instances** - Writer instance and configurable number of read replicas  
- **DB Subnet Group** - Database subnet group using provided VPC private subnets
- **Security Group** - VPC security group allowing MySQL traffic (port 3306) within VPC CIDR
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
