# MySQL Database on Kubernetes

Deploys and manages MySQL database instances on Kubernetes using the official Bitnami Helm chart with secure defaults and high availability support.

## Overview

This module provides a production-ready MySQL deployment on Kubernetes with automated configuration, security hardening, and scalability options. It supports both standalone and replicated architectures for high availability deployments.

## Environment as Dimension

The module is environment-aware and adapts based on:
- **Namespace isolation**: Each environment can deploy to separate Kubernetes namespaces
- **Resource naming**: Uses `var.environment.unique_name` to ensure unique resource names across environments
- **Configuration**: Environment-specific sizing and performance tuning
- **Security**: Environment-specific access controls and network policies

## Resources Created

- **StatefulSet**: MySQL database instances with persistent storage
- **Services**: ClusterIP services for internal database access with primary/replica endpoints
- **Secrets**: Automatically generated or user-provided MySQL root credentials
- **ConfigMaps**: MySQL configuration files optimized for Kubernetes
- **PersistentVolumeClaims**: Durable storage for MySQL data directories
- **Namespace**: Isolated namespace for MySQL resources (if not using default)

## Security Considerations

**Default Security Features:**
- Encryption at rest enabled through persistent volume encryption
- TLS/SSL encryption for client connections
- Non-root container execution for enhanced security
- Network policies available for traffic isolation
- Secure credential management through Kubernetes secrets
- 7-day binary log retention for point-in-time recovery
- Strong password requirements (minimum 8 characters)

**Access Control:**
- Root password can be auto-generated or explicitly set
- Database access restricted to authenticated connections only
- Service-based access control within Kubernetes cluster

## High Availability

The module supports MySQL replication for high availability:
- **Standalone mode** (replica_count = 1): Single MySQL instance for development
- **Replication mode** (replica_count > 1): Master-slave replication with read replicas
- **Automatic failover**: Built-in MySQL replication and Kubernetes StatefulSet guarantees
- **Data persistence**: Multi-zone persistent storage with automatic backup retention

## Backup and Recovery

**Automated Features:**
- Binary logging enabled with 7-day retention
- Point-in-time recovery support through MySQL binary logs
- Persistent volume snapshots (depends on storage class)
- Init script support for database restoration from existing backups

**Restore Operations:**
- Restore from existing PVC containing backup data
- Custom initialization scripts via ConfigMaps
- Import support for existing MySQL deployments