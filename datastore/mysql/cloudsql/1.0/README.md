# MySQL CloudSQL Module

[![Version](https://img.shields.io/badge/version-1.0-blue.svg)](https://github.com/facets-io/facets-modules)

## Overview

This module provisions a managed MySQL database using Google Cloud SQL with automated backups, high availability, and secure networking. It provides a developer-friendly interface for creating production-ready MySQL instances with optional read replicas and restore capabilities.

## Environment as Dimension

This module is environment-aware and will create unique resources per environment using the `environment.unique_name`. The following configurations adapt per environment:
- Instance naming includes environment identifier for uniqueness
- Cloud tags are automatically applied per environment
- Network configurations use environment-specific VPC details

## Resources Created

- **CloudSQL MySQL Instance** - Regional MySQL instance with automated backups
- **MySQL Database** - Initial application database with specified name  
- **Database User** - Root user with auto-generated secure password
- **Read Replicas** - Optional read-only replicas for improved performance
- **Private IP Configuration** - Secure private network connectivity only

## Security Considerations

This module implements several security best practices by default:
- **Private networking only** - No public IP addresses assigned
- **Encryption at rest and in transit** - All data encrypted automatically
- **Regional high availability** - Multi-zone deployment for resilience
- **Automated backups** - 7-day retention with point-in-time recovery
- **Secure password generation** - Random passwords for new instances
- **Network isolation** - Uses provided VPC for database subnet allocation

## Key Features

### Version Management
Supports MySQL versions 5.7, 8.0, and 8.4 with easy version selection through the interface.

### Backup & Restore Operations  
Built-in support for restoring from existing CloudSQL backups or cloning from other instances. When restoring, you can specify custom credentials for the new instance.

### Read Replica Support
Configure up to 5 read replicas for improved read performance and geographical distribution.

### Import Existing Resources
Import existing CloudSQL instances into Facets management using the imports configuration section.

### Auto-scaling Storage
Automatic disk resize enabled with intelligent limits to prevent runaway costs while ensuring adequate storage.

## Dependencies

This module requires:
- **GCP Cloud Account** (`@facets/gcp_cloud_account`) - Provides GCP provider configuration
- **VPC Network** (`@facets/gcp-network-details`) - Provides networking infrastructure for private IP setup

## Module Outputs

The module provides two output types:
- **Default Output** (`@facets/mysql-cloudsql`) - CloudSQL-specific instance details including connection names and IP addresses
- **Interfaces Output** (`@facets/mysql-interface`) - Standard MySQL connectivity interface with reader/writer endpoints

The interfaces output follows the standard pattern with separate reader and writer connection details, allowing applications to optimize their database access patterns.