# MySQL Aurora Cluster

A managed MySQL Aurora cluster with high availability, automated backups, and read replicas.

## Overview

This module provisions an AWS Aurora MySQL cluster with serverless v2 scaling capabilities. It provides a fully managed relational database service with automated backup, point-in-time recovery, and multi-AZ deployment for high availability.

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
- **Secrets Manager Secret** - Secure storage for database master password
- **Random Password** - Auto-generated secure password when not restoring from backup

## Security Considerations

This module implements several security best practices:

- **Encryption at rest** is always enabled for the Aurora cluster
- **Encryption in transit** is enforced for all database connections
- **Master password** is stored securely in AWS Secrets Manager
- **Network isolation** restricts database access to VPC CIDR blocks only
- **Backup retention** is set to 7 days with automated point-in-time recovery
- **Performance Insights** is enabled for database monitoring and troubleshooting

The module supports importing existing Aurora resources and restoring from backups while maintaining security standards.
