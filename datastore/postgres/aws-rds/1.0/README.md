# PostgreSQL RDS Module

![Version](https://img.shields.io/badge/version-1.0-blue) ![Cloud](https://img.shields.io/badge/cloud-AWS-orange)

## Overview

This module provisions a managed PostgreSQL database using Amazon RDS with enterprise-grade security defaults and operational best practices. It provides a developer-friendly interface while maintaining production-ready configurations for encryption, backup, and high availability.

## Environment as Dimension

This module is environment-aware and adapts configurations based on the deployment environment:

- **Resource Naming**: Incorporates `var.environment.unique_name` to ensure unique resource identifiers across environments
- **Tagging Strategy**: Applies environment-specific tags via `var.environment.cloud_tags` for consistent resource organization
- **Network Isolation**: Deploys within environment-specific VPC infrastructure provided through inputs

Environment-specific variations are handled through the infrastructure inputs rather than direct environment variables, maintaining consistency while allowing environment-appropriate networking and access controls.

## Resources Created

- **RDS PostgreSQL Instance** - Primary database instance with multi-AZ deployment for high availability
- **Read Replicas** - Optional read-only replicas for improved read performance and load distribution
- **DB Subnet Group** - Private subnet configuration ensuring database isolation from public networks  
- **Security Group** - Restrictive network access controls allowing database connections only from within the VPC
- **Random Credentials** - Secure master username and password generation when not restoring from backup

## Security Considerations

This module implements security-first defaults that cannot be disabled:

- **Encryption at Rest**: All database storage is encrypted using AWS-managed keys
- **Network Isolation**: Database instances are deployed in private subnets with no public access
- **Access Controls**: Security groups restrict database access to VPC CIDR blocks only
- **Backup Security**: Automated backups with 7-day retention and encrypted snapshots
- **Deletion Protection**: Prevents accidental database deletion in production environments
- **Performance Monitoring**: Performance Insights enabled for security event monitoring

Users should ensure proper IAM policies and VPC configurations are in place to maintain the security posture established by this module.
