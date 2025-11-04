# PostgreSQL CloudSQL Database

[![Terraform](https://img.shields.io/badge/terraform-v1.5.7-blue.svg)](https://www.terraform.io)
[![Google Cloud](https://img.shields.io/badge/gcp-cloudsql-blue.svg)](https://cloud.google.com/sql)

## Overview

This module provisions a managed PostgreSQL database using Google Cloud SQL with enterprise-grade security, high availability, and automated backup capabilities. It provides a developer-friendly interface while maintaining production-ready defaults for encryption, networking, and disaster recovery.

## Environment as Dimension

The module is environment-aware and automatically configures:
- **Instance naming**: Incorporates environment unique identifiers to prevent conflicts
- **Resource tagging**: Applies environment-specific cloud tags for resource management
- **Network isolation**: Uses environment-specific VPC and subnet configurations
- **Backup retention**: Maintains consistent 7-day backup policy across environments

## Resources Created

- **Cloud SQL PostgreSQL Instance**: Primary database instance with regional availability
- **Private Database**: Default application database with specified name
- **Master User**: Database user with generated secure password
- **Read Replicas**: Optional read-only replicas for scaling read workloads
- **Backup Configuration**: Automated daily backups with point-in-time recovery
- **Network Security**: Private IP configuration with SSL enforcement

## Security Considerations

This module implements security-first defaults:

**Network Security**: Database instances are deployed with private IP addresses only, requiring VPC access for connectivity. SSL connections are enforced for all database traffic.

**Access Control**: Master user credentials are automatically generated with strong passwords. When restoring from backup, explicit credential management is required to maintain security boundaries.

**Data Protection**: Encryption at rest and in transit is enabled by default. All instances use SSD storage for performance and security. Point-in-time recovery is configured with 7-day backup retention.

**Resource Protection**: Resources can be destroyed when needed for testing and development purposes. The module includes lifecycle rules to ignore disk size changes, allowing automatic storage scaling while protecting against unintended modifications.

**Import Safety**: When importing existing CloudSQL resources, the module maintains existing security configurations while bringing resources under Terraform management without disruption.