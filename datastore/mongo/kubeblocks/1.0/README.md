# MongoDB on Kubernetes with KubeBlocks

This Terraform module deploys and manages MongoDB database clusters on Kubernetes using [KubeBlocks](https://kubeblocks.io/) operator v1.0.1.

## Overview

KubeBlocks is a cloud-native data infrastructure platform that simplifies database operations on Kubernetes. This module leverages KubeBlocks to provide:

- **Production-Ready MongoDB**: Automated deployment with best practices
- **High Availability**: Replica sets with automatic failover
- **Backup & Restore**: Volume snapshots with point-in-time recovery
- **Volume Expansion**: Automatic storage scaling without downtime
- **Multi-Version Support**: MongoDB 4.4, 5.0, 6.0, 7.0, and 8.0

## Features

### Deployment Modes
- **Standalone Mode**: Single MongoDB instance for development/testing
- **Replication Mode**: Multi-node replica set for production (default)

> **Note**: Both modes use KubeBlocks **`replicaset` topology**. The replica count determines the behavior:
> - Standalone: 1 replica (no automatic failover)
> - Replication: 3-7 replicas (with automatic failover)

### Built-in Capabilities
- ✅ Automatic volume expansion (no downtime)
- ✅ Scheduled backups with retention policies
- ✅ Point-in-time restore from backups
- ✅ Pod anti-affinity for high availability
- ✅ Node selector and toleration support
- ✅ Termination policies (DoNotTerminate/Delete/WipeOut)
- ✅ Custom namespace support
- ✅ External access via LoadBalancer services

## Prerequisites

1. **KubeBlocks Operator**: Must be installed first
   - Use the `@facets/kubeblocks-operator` module
   - Ensures CRDs are available before cluster creation

2. **Kubernetes Cluster**: v1.25+ recommended
   - Storage class with `allowVolumeExpansion: true` for automatic expansion

3. **Storage Requirements**:
   - Default: 20Gi per replica
   - Supports dynamic provisioning via storage classes

## Usage

### Basic Deployment (Replication Mode)

```yaml
kind: mongo
flavor: k8s_kubeblocks
version: '1.0'
spec:
  mongodb_version: 8.0.8
  mode: replication
  replicas: 3
  resources:
    cpu_request: 500m
    cpu_limit: 1000m
    memory_request: 1Gi
    memory_limit: 2Gi
  storage:
    size: 20Gi
    storage_class: 'gp3-encrypted'
```

### Standalone Deployment

```yaml
kind: mongo
flavor: k8s_kubeblocks
version: '1.0'
spec:
  mongodb_version: 8.0.8
  mode: standalone  # Automatically sets replicas=1
  resources:
    cpu_request: 500m
    cpu_limit: 1000m
    memory_request: 1Gi
    memory_limit: 2Gi
  storage:
    size: 20Gi
```

### With Scheduled Backups

```yaml
kind: mongo
flavor: k8s_kubeblocks
version: '1.0'
spec:
  mongodb_version: 8.0.8
  mode: replication
  replicas: 3
  storage:
    size: 50Gi
  backup:
    enabled: true
    enable_schedule: true
    schedule_cron: "0 2 * * *"  # Daily at 2 AM
    retention_period: "7d"
```

### Restore from Backup

```yaml
kind: mongo
flavor: k8s_kubeblocks
version: '1.0'
spec:
  mongodb_version: 8.0.8
  mode: replication
  replicas: 3
  restore:
    enabled: true
    backup_name: "mongo-cluster-backup-20250125120000"
```

### External Access via LoadBalancer

Expose MongoDB cluster externally using cloud provider load balancers:

```yaml
kind: mongo
flavor: k8s_kubeblocks
version: '1.0'
spec:
  mongodb_version: 8.0.8
  mode: replication
  replicas: 3

  # External Access Configuration
  external_access:
    internal:  # Key name (max 15 chars)
      role: primary
      annotations:
        # GCP Internal Load Balancer
        cloud.google.com/load-balancer-type: "Internal"
        networking.gke.io/load-balancer-type: "Internal"

    public:
      role: secondary
      annotations:
        # AWS Network Load Balancer
        service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
        service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
```

**Important Notes**:
- **Key names must be 15 characters or less** (KubeBlocks service name limit: 25 chars)
- Each entry creates a separate LoadBalancer service
- `role` can be `primary` or `secondary` to target specific MongoDB nodes
- Use `annotations` for cloud-specific load balancer configuration
- External endpoints are exposed in outputs as `external_endpoints` (JSON)

**Cloud Provider Examples**:

<details>
<summary>AWS Network Load Balancer</summary>

```yaml
external_access:
  public:
    role: primary
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
      service.beta.kubernetes.io/aws-load-balancer-scheme: "internet-facing"
      service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled: "true"
```
</details>

<details>
<summary>GCP Internal Load Balancer</summary>

```yaml
external_access:
  internal:
    role: primary
    annotations:
      cloud.google.com/load-balancer-type: "Internal"
      networking.gke.io/load-balancer-type: "Internal"
```
</details>

<details>
<summary>Azure Standard Load Balancer</summary>

```yaml
external_access:
  public:
    role: primary
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-internal: "false"
      service.beta.kubernetes.io/azure-pip-name: "mongo-public-ip"
```
</details>

## Configuration Reference

### MongoDB Versions

KubeBlocks deploys **Percona Server for MongoDB**, a fully compatible drop-in replacement for MongoDB Community Edition with enterprise features.

| Version | Status | Notes |
|---------|--------|-------|
| 8.0.8   | ✅ Default | Latest stable (MongoDB 8.0) |
| 7.0.18  | ✅ Supported | Recommended for conservative deployments |
| 6.0.21  | ✅ Supported | LTS version |
| 5.0.29  | ✅ Supported | Extended support |
| 4.4.29  | ✅ Supported | Legacy support |

### Deployment Modes

#### Replication (Default)
- **Topology**: `replicaset` (KubeBlocks ClusterDefinition)
- **Replicas**: 1-7 instances (default: 3, recommended: 3 for production)
- **Use Case**: Production workloads requiring high availability
- **Features**: 
  - Automatic failover when primary fails
  - Read replicas for scaling read operations
  - Pod anti-affinity for distribution across nodes
  - Connection string includes all replicas for driver-level failover

#### Standalone
- **Topology**: `replicaset` (same as replication mode)
- **Replicas**: Fixed at 1
- **Use Case**: Development, testing, low-traffic applications
- **Features**: 
  - Simple single-node deployment
  - Lower resource requirements
  - No automatic failover
  - Simpler connection string

> **Technical Note**: KubeBlocks MongoDB addon has two topologies defined in its ClusterDefinition: `replicaset` (default) and `sharding`. This module currently uses only the `replicaset` topology for all deployments. The replica count differentiates between standalone (1 replica) and high-availability (3+ replicas) modes. Sharded cluster support is planned for v1.1.

### Termination Policies

| Policy | Behavior | Use Case |
|--------|----------|----------|
| `Delete` (default) | Deletes pods and PVCs | Standard cluster deletion |
| `DoNotTerminate` | Blocks cluster deletion | Production safety |
| `WipeOut` | Deletes everything including backups | Complete cleanup |

### Resource Allocation

```yaml
resources:
  cpu_request: "500m"    # Minimum CPU
  cpu_limit: "1000m"     # Maximum CPU
  memory_request: "1Gi"  # Minimum memory
  memory_limit: "2Gi"    # Maximum memory
```

**Sizing Guidelines**:
- **Development**: 500m CPU / 1Gi memory
- **Production (small)**: 1 CPU / 2Gi memory
- **Production (medium)**: 2 CPU / 4Gi memory
- **Production (large)**: 4+ CPU / 8Gi+ memory

### Storage Configuration

```yaml
storage:
  size: "20Gi"              # Initial size (expandable)
  storage_class: ""         # Empty = cluster default
```

**Important Notes**:
- ✅ Can be expanded (e.g., 20Gi → 50Gi)
- ❌ Cannot be reduced (e.g., 50Gi → 20Gi)
- Storage class must have `allowVolumeExpansion: true`

### Backup Configuration

```yaml
backup:
  enabled: true
  enable_schedule: true
  schedule_cron: "0 2 * * *"  # Cron expression
  retention_period: "7d"       # 7d, 30d, 1y, etc.
```

**Backup Methods**:
- **Volume Snapshot**: Fast, space-efficient (default)
- Stored in Kubernetes VolumeSnapshots
- Compatible with CSI drivers (AWS EBS, GCP PD, Azure Disk)

**Cron Schedule Examples**:
- `"0 2 * * *"` - Daily at 2 AM
- `"0 */6 * * *"` - Every 6 hours
- `"0 0 * * 0"` - Weekly on Sunday midnight

## Operations

### Volume Expansion

KubeBlocks automatically handles volume expansion:

1. Update `storage.size` in your configuration (e.g., 20Gi → 50Gi)
2. Apply the change
3. KubeBlocks creates an OpsRequest internally
4. PVCs are expanded without downtime

**No manual intervention required!**

### Backup & Restore

#### List Available Backups

```bash
kubectl get backup -n <namespace> -l app.kubernetes.io/instance=<cluster-name>
```

#### Restore Process

1. Note the backup name from the list
2. Create a new cluster with `restore.enabled: true`
3. Specify `restore.backup_name`
4. Cluster will be restored from the backup

**Important**: Restore creates a NEW cluster, doesn't overwrite existing.

### Monitoring

KubeBlocks exposes metrics on each pod:

```bash
# Port-forward to access metrics
kubectl port-forward -n <namespace> <pod-name> 9216:9216

# Access metrics
curl http://localhost:9216/metrics
```

**Key Metrics**:
- `mongodb_up` - Instance health
- `mongodb_connections` - Active connections
- `mongodb_memory_resident` - Memory usage
- `mongodb_opcounters_*` - Operation counters

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `kubeblocks_operator` | `@facets/kubeblocks-operator` | Yes | KubeBlocks operator instance |
| `kubernetes_cluster` | `@facets/kubernetes-details` | Yes | Target Kubernetes cluster |
| `node_pool` | `@facets/kubernetes_nodepool` | No | Node pool for pod scheduling |

## Outputs

| Name | Type | Description |
|------|------|-------------|
| `namespace` | string | Namespace where cluster is deployed |
| `service_name` | string | Primary service name |
| `replica_set_name` | string | MongoDB replica set name |
| `database_name` | string | Admin database name |
| `username` | string | Admin username (root) |
| `password` | string | Admin password (sensitive) |
| `replica_count` | string | Number of replicas |
| `replica_hosts` | string | Comma-separated replica hosts |
| `max_connections` | string | Maximum connections (65536) |
| `external_endpoints` | JSON string | External LoadBalancer endpoints (if configured) |

### Connection Examples

**Replica Set (Replication Mode with 3 replicas)**:
```
mongodb://root:<password>@mongo-0.mongo-headless:27017,mongo-1.mongo-headless:27017,mongo-2.mongo-headless:27017/admin?replicaSet=<cluster-name>
```

**Standalone Mode (1 replica)**:
```
mongodb://root:<password>@<cluster-name>-mongodb:27017/admin
```

**External Access (via LoadBalancer)**:

When external access is configured, the `external_endpoints` output provides LoadBalancer details in JSON format:

```json
{
  "internal": {
    "host": "10.128.0.50",
    "port": "27017",
    "role": "primary"
  },
  "public": {
    "host": "a1b2c3d4.us-east-1.elb.amazonaws.com",
    "port": "27017",
    "role": "secondary"
  }
}
```

Connection string using external endpoint:
```
mongodb://root:<password>@10.128.0.50:27017/admin
```

## Troubleshooting

### Cluster Not Starting

```bash
# Check cluster status
kubectl get cluster <cluster-name> -n <namespace> -o yaml

# Check pod logs
kubectl logs -n <namespace> <pod-name>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Storage Issues

```bash
# Check PVC status
kubectl get pvc -n <namespace>

# Verify storage class supports expansion
kubectl get sc <storage-class> -o yaml | grep allowVolumeExpansion
```

### Backup Failures

```bash
# Check backup status
kubectl get backup <backup-name> -n <namespace> -o yaml

# Check backup policy
kubectl get backuppolicy -n <namespace>

# Verify VolumeSnapshot CRDs exist
kubectl get crd | grep volumesnapshot
```

## Architecture

```
┌─────────────────────────────────────────┐
│          KubeBlocks Operator            │
│    (Manages MongoDB Lifecycle)          │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│        MongoDB Cluster CR               │
│  - ClusterDefinition: mongodb           │
│  - Topology: replicaset                 │
│  - ComponentDef: mongodb-1.0.1          │
│  - Backup configuration                 │
│  - Resource requirements                │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│         StatefulSet                     │
│  - mongo-0, mongo-1, mongo-2            │
│  - Each with PVC (data volume)          │
│  - Pod anti-affinity enabled            │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│         Services                        │
│  - Primary: <name>-mongodb              │
│  - Headless: <name>-mongodb-headless    │
└─────────────────────────────────────────┘
```

## Known Limitations

1. **Sharded Clusters**: Not supported in v1.0 (planned for v1.1)
   - KubeBlocks has `sharding` topology available
   - Requires mongos routers, config servers, and shard components
2. **Version Downgrade**: Not supported (only upgrades)
3. **Cross-Region**: Single region deployment only
4. **Storage Reduction**: Cannot shrink volume size

## References

- [KubeBlocks MongoDB Documentation](https://kubeblocks.io/docs/preview/kubeblocks-for-mongodb/01-overview)
- [MongoDB Official Documentation](https://docs.mongodb.com/)
- [KubeBlocks GitHub](https://github.com/apecloud/kubeblocks)
- [Percona Server for MongoDB](https://www.percona.com/software/mongodb/percona-server-for-mongodb)

## Support

For issues or questions:
1. Check KubeBlocks operator logs
2. Review cluster events and pod logs
3. Consult KubeBlocks documentation
4. Contact your platform team

## License

This module follows the same license as the KubeBlocks project (Apache 2.0).
