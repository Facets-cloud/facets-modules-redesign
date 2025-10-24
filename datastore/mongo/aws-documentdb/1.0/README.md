# MongoDB DocumentDB Module

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Cloud](https://img.shields.io/badge/cloud-AWS-orange)

## Overview

This module creates a MongoDB-compatible database cluster using AWS DocumentDB. It provides a fully managed document database service that supports MongoDB workloads with enterprise-grade features including automatic backups, point-in-time recovery, and high availability.

## Environment as Dimension

This module is environment-aware and provisions resources with environment-specific naming and tagging:
- **Resource Naming**: All resources are named using `${instance_name}-${environment.unique_name}` pattern
- **Environment Tags**: Applies `environment.cloud_tags` to all resources for proper governance and billing
- **Network Isolation**: Deploys within environment-specific VPC and subnets
- **Configuration Consistency**: Uses the same configuration across environments unless explicitly overridden

## Resources Created

- **DocumentDB Cluster**: Primary database cluster with configurable engine version and port
- **DocumentDB Instances**: Compute instances within the cluster (1-16 instances)
- **Subnet Group**: Database subnet group using private subnets from VPC
- **Security Group**: Network security group allowing access only from VPC CIDR
- **Parameter Group**: Cluster parameter group with TLS encryption enabled
- **Random Password**: Secure password generation for new clusters (when not restoring)

## Security Considerations

The module implements security best practices by default:

**Encryption**: All data is encrypted at rest using AWS managed keys. TLS encryption is enabled for all client connections through the parameter group configuration.

**Network Security**: The security group restricts access to the DocumentDB port only from within the VPC CIDR block. The cluster is deployed in private subnets with no direct internet access.

**Access Control**: Uses strong password policies with auto-generated 16-character passwords including special characters. When restoring from snapshots, credentials must be explicitly provided.

**Backup Security**: Automatic backups are retained for 7 days with point-in-time recovery capability. Final snapshots are created before cluster deletion to prevent data loss.

**Resource Protection**: Lifecycle rules prevent accidental destruction of the database cluster and instances. The ignore_changes configuration prevents recreation for network-related attributes that would cause downtime.