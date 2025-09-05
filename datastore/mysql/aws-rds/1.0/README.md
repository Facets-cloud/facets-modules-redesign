# MySQL RDS Database Module v1.0

## Overview

This Facets module provisions a managed MySQL database instance on AWS RDS with high availability, automated backups, and read replicas. The module provides a secure, production-ready MySQL database with encryption at rest and in transit, following AWS best practices for database deployment.

## Environment as Dimension

This module is environment-aware and will create unique resources per environment using the `var.environment.unique_name` for resource naming. Database configurations remain consistent across environments, but networking and scaling settings can be adjusted per environment through the spec configuration.

## Resources Created

- **RDS MySQL Instance**: Primary database instance with specified version and sizing
- **DB Subnet Group**: Private subnet group for database networking within VPC
- **Security Group**: Dedicated security group allowing MySQL access (port 3306) from VPC CIDR
- **Read Replicas**: Optional read-only database replicas for improved read performance
- **Random Password**: Automatically generated secure master password (16 characters with special characters)

## Security Considerations

### Password Management
This module uses **random password generation only** and does not utilize AWS Secrets Manager. The generated password is stored in Terraform state and made available through the module's output interfaces. For production deployments, consider implementing external secret management solutions.

### Network Security
- Database instances are deployed in private subnets only (never publicly accessible)
- Security group restricts access to MySQL port 3306 from VPC CIDR block only
- All connections use encryption in transit (SSL/TLS)

### Data Protection
- Storage encryption at rest is always enabled using AWS managed keys
- Automated backups are configured with 7-day retention period
- High availability is enabled by default with Multi-AZ deployment
- Final snapshots are created before deletion (disabled for testing environments)

### Performance and Monitoring
- Performance Insights enabled for supported instance classes (disabled for db.t3.micro and db.t3.small)
- CloudWatch logs exports enabled for error, general, and slow query logs
- Monitoring interval disabled to avoid IAM role requirements

## Restore Operations

The module supports restoring from existing RDS backups or snapshots by setting `restore_from_backup: true` and providing:
- Source database instance identifier
- Restored database master username
- Restored database master password

When restoring, the module uses the provided credentials instead of generating new ones.

## Import Support

Existing AWS RDS resources can be imported into this module using the import configuration:
- **DB Instance**: Import existing RDS instance using its identifier
- **DB Subnet Group**: Import existing subnet group by name  
- **Security Group**: Import existing security group by ID

## Best Practices

- Instance classes db.t3.micro and db.t3.small do not support Performance Insights
- Read replicas are created in the same VPC and security group as the primary instance
- Storage autoscaling is configured when max_allocated_storage is greater than allocated_storage
- Backup and maintenance windows are scheduled during low-traffic periods (3-4 AM UTC)
- All resources include comprehensive tagging for resource management and cost allocation
