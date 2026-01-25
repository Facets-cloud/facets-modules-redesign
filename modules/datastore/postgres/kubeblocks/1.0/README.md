# PostgreSQL Database Cluster - KubeBlocks Module

![Version](https://img.shields.io/badge/version-1.0-blue)
![Cloud](https://img.shields.io/badge/cloud-kubernetes-326CE5)

## Overview

This module creates and manages production-ready PostgreSQL database clusters on Kubernetes using the KubeBlocks operator (v1.0.1). It provides a developer-friendly interface for deploying PostgreSQL instances with built-in high availability, backup/restore capabilities, and automated lifecycle management.

KubeBlocks handles cluster operations including provisioning, scaling, failover, and backup orchestration while this module abstracts the complexity behind a simple configuration interface.

## Environment as Dimension

This module is **environment-aware** and automatically adapts to different deployment contexts:

- **Namespace**: Uses `var.environment.namespace` by default, with optional override via `namespace_override` for multi-tenant scenarios
- **Cloud Tags**: Automatically applies `var.environment.cloud_tags` to all created resources for cost tracking and governance
- **Resource Names**: Generates unique cluster names scoped to the environment using standardized naming conventions
- **Storage Classes**: Can be customized per environment (e.g., premium SSD for production, standard for dev)

The module respects environment boundaries while allowing configuration overrides where needed, making it suitable for deploying the same PostgreSQL cluster configuration across dev, staging, and production environments.

## Resources Created

This module creates the following Kubernetes resources:

- **Cluster** (KubeBlocks CRD) - Main PostgreSQL cluster definition with componentSpecs for primary/replica configuration
- **Namespace** - Optional custom namespace for cluster isolation (conditionally created when override specified)
- **Service (Primary)** - Auto-created by KubeBlocks for write operations targeting primary instance (ports 5432 PostgreSQL, 6432 PgBouncer)
- **Service (Read)** - Terraform-managed read-only service targeting secondary replicas in replication mode (ports 5432, 6432)
- **Secret** - Auto-created by KubeBlocks containing connection credentials with format `{cluster-name}-conn-credential`
- **PersistentVolumeClaims** - Storage volumes for PostgreSQL data (one per replica, expandable via spec updates)
- **Pods** - PostgreSQL instances managed by KubeBlocks StatefulSet controller with configurable resource limits
- **BackupPolicy** - Embedded backup configuration when backup scheduling is enabled
- **Restore Annotations** - Cluster annotations for restore-from-backup functionality

## Deployment Modes

### Standalone Mode
Single PostgreSQL instance suitable for development or non-critical workloads. Provides basic functionality with minimal resource overhead and simplified configuration.

### Replication Mode (Recommended)
High-availability setup with one primary and configurable read replicas (1-5 instances). Features:
- Automatic failover when primary fails using KubeBlocks replication topology
- Read scaling via dedicated read-only service targeting secondary replicas
- Pod anti-affinity to distribute replicas across different Kubernetes nodes
- Volume-snapshot backup support for point-in-time recovery

## High Availability Configuration

In replication mode, the module provides:

- **Pod Anti-Affinity**: Distributes replicas across different Kubernetes nodes to survive node failures
- **Topology**: Uses KubeBlocks `replication` topology for automatic primary/secondary streaming replication
- **Read Service**: Dedicated endpoint `{cluster-name}-postgresql-read` for read-only queries that load-balances across secondary replicas
- **Failure Handling**: KubeBlocks automatically promotes secondary to primary during failover scenarios
- **Node Tolerance**: Configured to schedule on spot instances and specialty nodes with appropriate tolerations
- **PgBouncer**: Built-in connection pooling available on port 6432 for all endpoints

## Backup & Restore

### Backup Configuration
Supports automated volume-snapshot backups integrated with KubeBlocks' native backup system:
- **Method**: Volume-snapshot using Kubernetes CSI snapshots
- **Schedule**: Configurable cron expression for automated backups (e.g., `"0 2 * * *"` for daily at 2 AM)
- **Retention**: Configurable retention period (7d, 30d, 1y) managed by KubeBlocks
- **Integration**: Embedded in cluster spec using KubeBlocks ClusterBackup API

### Restore from Backup
Clusters can be restored from existing backups using annotation-based restore:
- Provide backup name in `restore.backup_name` configuration
- KubeBlocks orchestrates restore process automatically during cluster creation
- Extended timeout (60 minutes) during restore operations for large datasets
- Restore status tracked via cluster phase monitoring

## Storage Management

The module supports dynamic storage expansion through KubeBlocks:
- Initial size specified in `storage.size` configuration
- Expansion: Update size value and apply - KubeBlocks handles PVC expansion automatically
- **Cannot be reduced** once provisioned due to Kubernetes PVC limitations
- Storage class customization per environment supported
- Automatic volume claim template management

## Version Support

Supported PostgreSQL versions with KubeBlocks v1.0.1:
- **16.4.0** (default, latest stable)
- **15.7.0** (stable LTS)
- **14.8.0** (older LTS)
- **12.15.0** (legacy support)

Component definitions automatically map to KubeBlocks releases based on major version (e.g., `postgresql-16-1.0.1`).

## Connection Details

The module exposes two connection interfaces through KubeBlocks auto-generated services:

**Writer Interface** (Primary)
- Direct connection to primary instance for write operations
- Hostname: `{cluster-name}-postgresql.{namespace}.svc.cluster.local`
- PostgreSQL Port: 5432 (direct connection)
- PgBouncer Port: 6432 (connection pooling)
- Always available regardless of deployment mode

**Reader Interface** (Read Replicas)
- Load-balanced connection to secondary replicas (replication mode only)
- Hostname: `{cluster-name}-postgresql-read.{namespace}.svc.cluster.local`
- PostgreSQL Port: 5432 (direct connection)
- PgBouncer Port: 6432 (connection pooling)
- Falls back to writer endpoint in standalone mode

Connection credentials automatically generated by KubeBlocks and stored in Kubernetes secrets.

## PgBouncer Connection Pooling

All PostgreSQL instances include PgBouncer connection pooler:
- Available on port 6432 for both writer and reader endpoints
- Reduces connection overhead and improves performance under high load
- Transparent to applications - use same credentials as direct PostgreSQL connection
- Recommended for web applications and services with frequent short-lived connections

## Security Considerations

- **Credentials**: Auto-generated by KubeBlocks, stored in Kubernetes Secrets, marked sensitive in outputs
- **Network**: Services use ClusterIP by default (internal cluster access only)
- **Secrets Management**: All passwords and connection strings marked as sensitive
- **RBAC**: Requires permissions for CRD management, namespace creation, and service operations
- **Pod Security**: Tolerations configured for spot nodes and specialty workloads
- **Cluster Policies**: Configurable termination policies (DoNotTerminate, Delete, WipeOut)

## Resource Requirements

Default resource allocations per PostgreSQL instance:
- CPU Request: 500m (minimum guaranteed)
- CPU Limit: 1000m (maximum allowed)
- Memory Request: 512Mi (minimum guaranteed)
- Memory Limit: 1Gi (maximum allowed)
- Storage: 20Gi (initial allocation, expandable)

These are fully configurable through the module spec and scale with replica count.

## Dependencies

This module requires two critical inputs:

1. **KubeBlocks Operator** - Must be deployed with CRDs ready and release tracking
2. **Kubernetes Cluster** - Target cluster with sufficient resources and storage classes

The operator dependency uses release_id tracking to ensure proper lifecycle sequencing and prevent race conditions during cluster provisioning.
