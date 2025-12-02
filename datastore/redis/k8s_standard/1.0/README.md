# Redis Cluster - KubeBlocks Module

![Version](https://img.shields.io/badge/version-1.0-blue)
![Cloud](https://img.shields.io/badge/cloud-kubernetes-326CE5)

## Overview

This module creates and manages production-ready Redis clusters on Kubernetes using the KubeBlocks operator (v1.0.1). It provides a developer-friendly interface for deploying Redis instances with built-in high availability, backup/restore capabilities, and automated lifecycle management.

KubeBlocks handles cluster operations including provisioning, scaling, failover, and backup orchestration while this module abstracts the complexity behind a simple configuration interface.

## Environment as Dimension

This module is **environment-aware** and automatically adapts to different deployment contexts:

- **Namespace**: Uses `var.environment.namespace` by default, with optional override via `namespace_override` for multi-tenant scenarios
- **Cloud Tags**: Automatically applies `var.environment.cloud_tags` to all created resources for cost tracking and governance
- **Resource Names**: Generates unique cluster names scoped to the environment using standardized naming conventions
- **Storage Classes**: Can be customized per environment (e.g., premium SSD for production, standard for dev)

The module respects environment boundaries while allowing configuration overrides where needed, making it suitable for deploying the same Redis cluster configuration across dev, staging, and production environments.

## Resources Created

This module creates the following Kubernetes resources:

- **Cluster** (KubeBlocks CRD) - Main Redis cluster definition with componentSpecs for primary/replica configuration
- **Namespace** - Optional custom namespace for cluster isolation (conditionally created when override specified)
- **Service (Primary)** - Auto-created by KubeBlocks for write operations targeting primary instance (port 6379)
- **Service (Read)** - Terraform-managed read-only service targeting secondary replicas in replication mode (port 6379)
- **Secret** - Auto-created by KubeBlocks containing connection credentials with format `{cluster-name}-conn-credential`
- **PersistentVolumeClaims** - Storage volumes for Redis data (one per replica, expandable via spec updates)
- **Pods** - Redis instances managed by KubeBlocks StatefulSet controller with configurable resource limits
- **Sentinel** - Redis Sentinel for high availability in replication mode (automatic failover and monitoring)
- **BackupPolicy** - Embedded backup configuration when backup scheduling is enabled
- **Restore Annotations** - Cluster annotations for restore-from-backup functionality

## Deployment Modes

### Standalone Mode
Single Redis instance suitable for development or non-critical workloads. Provides basic functionality with minimal resource overhead and simplified configuration. No high availability or failover.

### Replication Mode (Recommended for HA)
High-availability setup with Redis Sentinel managing one primary and configurable read replicas (1-5 instances). Features:
- Automatic failover when primary fails using Redis Sentinel
- Read scaling via dedicated read-only service targeting secondary replicas
- Pod anti-affinity to distribute replicas across different Kubernetes nodes
- Volume-snapshot backup support for point-in-time recovery
- Sentinel-based health monitoring and automatic leader election

### Redis Cluster Mode (Recommended for Scale)
Sharded Redis Cluster for horizontal scaling with 3-10 shards. Features:
- Automatic data sharding across multiple master nodes
- Each shard can have configurable replicas for high availability
- Horizontal scaling by adding more shards
- Built-in cluster management and rebalancing
- Client-side routing with CLUSTER commands
- Best for datasets larger than single-node memory capacity

## High Availability Configuration

In replication and redis-cluster modes, the module provides:

- **Pod Anti-Affinity**: Distributes replicas across different Kubernetes nodes to survive node failures
- **Topology**: 
  - Replication mode: Uses Redis Sentinel for automatic failover and monitoring
  - Redis Cluster mode: Uses native Redis Cluster topology with distributed hash slots
- **Read Service**: Dedicated endpoint `{cluster-name}-redis-read` for read-only queries (replication mode only)
- **Failure Handling**: 
  - Replication: Sentinel automatically promotes secondary to primary during failover
  - Cluster: Automatic failover within each shard, data remains available
- **Node Tolerance**: Configured to schedule on spot instances and specialty nodes with appropriate tolerations

## Backup & Restore

### Backup Configuration
Supports automated volume-snapshot backups integrated with KubeBlocks' native backup system:
- **Method**: Volume-snapshot using Kubernetes CSI snapshots
- **Schedule**: Configurable cron expression for automated backups (e.g., `"0 2 * * *"` for daily at 2 AM)
- **Retention**: Configurable retention period (7d, 30d, 1y) managed by KubeBlocks
- **Integration**: Embedded in cluster spec using KubeBlocks ClusterBackup API
- **Persistence**: Redis AOF (Append Only File) or RDB snapshots backed up to persistent volumes

### Restore from Backup
Clusters can be restored from existing backups using annotation-based restore:
- Provide backup name in `restore.backup_name` configuration
- KubeBlocks orchestrates restore process automatically during cluster creation
- Extended timeout (60 minutes) during restore operations for large datasets
- Restore status tracked via cluster phase monitoring
- Data consistency guaranteed through Redis persistence mechanisms

## Storage Management

The module supports dynamic storage expansion through KubeBlocks:
- Initial size specified in `storage.size` configuration
- Expansion: Update size value and apply - KubeBlocks handles PVC expansion automatically
- **Cannot be reduced** once provisioned due to Kubernetes PVC limitations
- Storage class customization per environment supported
- Automatic volume claim template management
- Redis persistence modes: AOF and RDB snapshot supported

## Version Support

Supported Redis versions with KubeBlocks v1.0.1:
- **7.2.4** (default, latest stable with enhanced features)
- **7.0.6** (LTS version for stability)

Component definitions automatically map to KubeBlocks releases (e.g., `redis-7.2-1.0.1`).

## Connection Details

The module exposes two connection interfaces through KubeBlocks auto-generated services:

**Writer Interface** (Primary)
- Direct connection to primary instance for write operations
- Hostname: `{cluster-name}-redis.{namespace}.svc.cluster.local`
- Port: 6379
- Always available regardless of deployment mode
- Supports all Redis commands including writes

**Reader Interface** (Read Replicas - Replication Mode Only)
- Load-balanced connection to secondary replicas
- Hostname: `{cluster-name}-redis-read.{namespace}.svc.cluster.local`
- Port: 6379
- Falls back to writer endpoint in standalone/cluster modes
- Read-only operations for load distribution

**Redis Cluster Mode**
- Applications must use Redis Cluster-aware clients
- Clients perform client-side routing based on hash slots
- CLUSTER commands available for topology discovery
- Connection string includes all cluster nodes

Connection credentials automatically generated by KubeBlocks and stored in Kubernetes secrets with password protection.

## Security Considerations

- **Credentials**: Auto-generated by KubeBlocks, stored in Kubernetes Secrets, marked sensitive in outputs
- **Authentication**: Redis AUTH enabled by default with secure password generation
- **Network**: Services use ClusterIP by default (internal cluster access only)
- **Secrets Management**: All passwords and connection strings marked as sensitive
- **RBAC**: Requires permissions for CRD management, namespace creation, and service operations
- **Pod Security**: Tolerations configured for spot nodes and specialty workloads
- **Cluster Policies**: Configurable termination policies (Delete, DoNotTerminate, WipeOut)
- **Data Protection**: AOF and RDB persistence for data durability

## Resource Requirements

Default resource allocations per Redis instance:
- CPU Request: 200m (minimum guaranteed)
- CPU Limit: 500m (maximum allowed)
- Memory Request: 256Mi (minimum guaranteed)
- Memory Limit: 512Mi (maximum allowed)
- Storage: 10Gi (initial allocation, expandable)

These are fully configurable through the module spec and scale with replica count. For Redis Cluster mode, resources multiply by number of shards.

## Redis-Specific Features

### Persistence Options
- **AOF (Append Only File)**: Write-ahead log for durability
- **RDB Snapshots**: Point-in-time snapshots for backup
- **Hybrid Mode**: Combination of AOF and RDB for best performance and durability

### Data Structures Supported
- Strings, Lists, Sets, Sorted Sets, Hashes
- Bitmaps, HyperLogLogs, Streams
- Geospatial indexes
- Pub/Sub messaging

### Performance Features
- In-memory data structure store
- Millisecond latency for read/write operations
- Pipelining and transaction support
- Lua scripting for server-side logic

## Deployment Mode Comparison

| Feature | Standalone | Replication | Redis Cluster |
|---------|------------|-------------|---------------|
| High Availability | ❌ No | ✅ Yes (Sentinel) | ✅ Yes (Built-in) |
| Horizontal Scaling | ❌ No | ⚠️ Read-only | ✅ Yes (Sharding) |
| Automatic Failover | ❌ No | ✅ Yes | ✅ Yes |
| Data Sharding | ❌ No | ❌ No | ✅ Yes |
| Memory Capacity | Single Node | Single Node | Multi-Node |
| Complexity | Low | Medium | High |
| Use Case | Dev/Test | Production HA | Large Datasets |

## Dependencies

This module requires two critical inputs:

1. **KubeBlocks Operator** - Must be deployed with CRDs ready and release tracking
2. **Kubernetes Cluster** - Target cluster with sufficient resources and storage classes

The operator dependency uses release_id tracking to ensure proper lifecycle sequencing and prevent race conditions during cluster provisioning.

## Operational Notes

### Redis Cluster Mode Considerations
- Minimum 3 shards required for cluster formation
- Data automatically distributed across shards using hash slots
- Applications must use cluster-aware Redis clients
- Resharding operations supported for adding/removing nodes
- Multi-key operations limited to same hash slot

### Sentinel Mode Considerations
- Sentinel quorum automatically configured for failover decisions
- Sentinel monitors master and replica health continuously
- Automatic promotion of replica to master during failures
- Manual failover commands supported via Sentinel API

### Performance Tuning
- Adjust maxmemory and eviction policies via Redis configuration
- Enable AOF for durability or RDB for performance
- Configure connection pooling in applications
- Monitor memory usage and key eviction metrics
