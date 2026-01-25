# GCP Managed Kafka Cluster Module

This module creates and manages GCP Managed Service for Apache Kafka clusters with secure defaults, automatic scaling, and optional Kafka Connect cluster support.

## Features

- ✅ **Managed Kafka Cluster**: Fully managed Apache Kafka service on GCP
- ✅ **KMS Encryption**: Automatic encryption at rest with Cloud KMS
- ✅ **Auto Rebalancing**: Automatic rebalancing on scale-up operations
- ✅ **Kafka Connect Support**: Optional Kafka Connect cluster for connectors
- ✅ **VPC Integration**: Secure deployment in private VPC networks
- ✅ **Multiple Kafka Versions**: Support for Kafka 3.4, 3.5, 3.6, 3.7
- ✅ **Flexible Sizing**: Configure vCPUs (3-48), memory (3-48 GB), and disk (100-10000 GB)

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GCP Managed Kafka                        │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         Kafka Cluster (google_managed_kafka_cluster) │   │
│  │                                                        │   │
│  │  • Kafka Brokers (vCPU: 3-48, Memory: 3-48 GB)      │   │
│  │  • KMS Encryption (90-day key rotation)              │   │
│  │  • Auto Rebalance on Scale Up                        │   │
│  │  • VPC Network Integration                           │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Kafka Connect Cluster (Optional)                    │   │
│  │  (google_managed_kafka_connect_cluster)              │   │
│  │                                                        │   │
│  │  • Connect Workers (Configurable: 3-48 vCPUs)        │   │
│  │  • Memory (Configurable: 3-48 GB)                    │   │
│  │  • DNS Domain for Kafka Cluster Visibility           │   │
│  │  • Supports Source/Sink Connectors                   │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐   │
│  │         Cloud KMS                                     │   │
│  │  • Key Ring: {cluster-name}-keyring                  │   │
│  │  • Crypto Key: {cluster-name}-key                    │   │
│  │  • Rotation: Every 90 days                           │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## Usage

### Basic Kafka Cluster

```yaml
kind: kafka
flavor: gcp-msk
version: '1.0'
spec:
  version_config:
    kafka_version: '3.7'
  sizing:
    vcpu_count: 6
    memory_gb: 12
    disk_size_gb: 500
```

### Kafka Cluster with Connect Support (Default Capacity)

```yaml
kind: kafka
flavor: gcp-msk
version: '1.0'
spec:
  version_config:
    kafka_version: '3.7'
  sizing:
    vcpu_count: 6
    memory_gb: 12
    disk_size_gb: 500
  connect_cluster:
    enabled: true  # Enables Kafka Connect with defaults (12 vCPUs, 20 GB)
```

### Kafka Cluster with Custom Connect Capacity

```yaml
kind: kafka
flavor: gcp-msk
version: '1.0'
spec:
  version_config:
    kafka_version: '3.7'
  sizing:
    vcpu_count: 6
    memory_gb: 12
    disk_size_gb: 500
  connect_cluster:
    enabled: true
    vcpu_count: 24  # Custom: 24 vCPUs for Connect workers
    memory_gb: 48   # Custom: 48 GB memory
```

### Production Configuration with Connect

```yaml
kind: kafka
flavor: gcp-msk
version: '1.0'
spec:
  version_config:
    kafka_version: '3.7'
  sizing:
    vcpu_count: 24
    memory_gb: 32
    disk_size_gb: 5000
  connect_cluster:
    enabled: true
    vcpu_count: 24
    memory_gb: 32
```

## Configuration Parameters

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `version_config.kafka_version` | string | Kafka version: '3.4', '3.5', '3.6', or '3.7' |
| `sizing.vcpu_count` | number | Number of virtual CPUs (3-48) |
| `sizing.memory_gb` | number | Memory in gigabytes (3-48) |
| `sizing.disk_size_gb` | number | Persistent disk size per broker (100-10000 GB) |

### Optional Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `connect_cluster.enabled` | boolean | false | Enable Kafka Connect cluster |
| `connect_cluster.vcpu_count` | number | 12 | vCPUs for Connect cluster (3-48) |
| `connect_cluster.memory_gb` | number | 20 | Memory for Connect cluster in GB (3-48) |

## Kafka Versions

| Version | Status | Features |
|---------|--------|----------|
| **3.7** | ✅ Latest | Latest features and improvements |
| **3.6** | ✅ Stable | Production-ready |
| **3.5** | ✅ Stable | Production-ready (default) |
| **3.4** | ✅ Stable | Production-ready |

**Recommendation**: Use **3.7** for new deployments to get the latest features and security updates.

## Sizing Guidelines

### Development/Testing

```yaml
sizing:
  vcpu_count: 3      # Minimum
  memory_gb: 3       # Minimum
  disk_size_gb: 100  # Minimum
```

- **Use Case**: Development, testing, proof-of-concepts
- **Throughput**: Low volume (< 10 MB/s)
- **Topics**: < 10 topics

### Small Production

```yaml
sizing:
  vcpu_count: 6
  memory_gb: 12
  disk_size_gb: 500
```

- **Use Case**: Small production workloads
- **Throughput**: Medium volume (10-50 MB/s)
- **Topics**: 10-50 topics

### Medium Production

```yaml
sizing:
  vcpu_count: 12
  memory_gb: 24
  disk_size_gb: 2000
```

- **Use Case**: Standard production workloads
- **Throughput**: High volume (50-200 MB/s)
- **Topics**: 50-200 topics

### Large Production

```yaml
sizing:
  vcpu_count: 24
  memory_gb: 32
  disk_size_gb: 5000
```

- **Use Case**: Large-scale production workloads
- **Throughput**: Very high volume (> 200 MB/s)
- **Topics**: 200+ topics

## Kafka Connect Cluster

Enable Kafka Connect to run data integration connectors with configurable capacity:

```yaml
# Minimal configuration (uses defaults)
connect_cluster:
  enabled: true

# Custom capacity configuration
connect_cluster:
  enabled: true
  vcpu_count: 24  # 3-48 vCPUs (default: 12)
  memory_gb: 48   # 3-48 GB (default: 20)
```

### What Gets Created:

- **Connect Cluster ID**: `{kafka-cluster-name}-connect`
- **Capacity**: Configurable vCPUs (3-48) and memory (3-48 GB)
  - Default: 12 vCPUs, 20 GB memory
  - Can be customized based on connector workload
- **Network**: Same VPC as Kafka cluster
- **DNS Configuration**: Kafka cluster DNS made visible to Connect workers

### Use Cases:

1. **Pub/Sub Integration**: Stream Kafka data to Google Cloud Pub/Sub
2. **BigQuery Integration**: Load Kafka data into BigQuery
3. **Cloud Storage**: Archive Kafka data to GCS
4. **Database Connectors**: JDBC source/sink connectors
5. **MirrorMaker2**: Replicate data between Kafka clusters

### When to Enable:

✅ **Enable if you need:**
- Data integration with GCP services
- External database connectivity
- Cluster replication (MirrorMaker2)
- Custom source/sink connectors

❌ **Disable if:**
- Only using Kafka for direct produce/consume
- No connector requirements
- Cost optimization for simple use cases

## Security Features

### 1. Encryption at Rest (KMS)

- **Automatic**: All data encrypted with Cloud KMS
- **Key Rotation**: Automatic 90-day rotation
- **Key Ring**: `{cluster-name}-keyring`
- **Crypto Key**: `{cluster-name}-key`
- **IAM**: Kafka service account auto-configured

### 2. Network Security

- **VPC Integration**: Cluster deployed in private subnet
- **No Public Access**: Only accessible within VPC
- **Service Connect**: Uses Private Service Connect (PSC)

### 3. Resource Protection

- **Lifecycle Protection**: `prevent_destroy = true` on all resources
- **Prevents Accidental Deletion**: Kafka cluster, KMS keys, Connect cluster

## Input Dependencies

This module requires:

```yaml
inputs:
  gcp_cloud_account:
    type: '@facets/gcp_cloud_account'
    description: GCP project and region configuration
    
  vpc_network:
    type: '@facets/gcp-network-details'
    description: VPC network with private subnet
```

### Network Requirements:

- **Subnet CIDR**: Minimum /22 (1024 addresses) for Kafka cluster
- **Additional Subnet** (if Connect enabled): /22 for Connect cluster
- **Private Subnet**: Must be in same region as Kafka cluster

## Outputs

The module exposes the following outputs:

### Kafka Cluster Outputs

| Output | Type | Description |
|--------|------|-------------|
| `cluster_id` | string | Kafka cluster ID |
| `location` | string | GCP location/region |
| `cluster_name` | string | Full cluster name |
| `kafka_version` | string | Kafka version deployed |

### Kafka Connect Outputs (when enabled)

| Output | Type | Description |
|--------|------|-------------|
| `connect_cluster_id` | string | Connect cluster ID (or null) |
| `connect_cluster_location` | string | Connect cluster location (or null) |
| `connect_cluster_state` | string | Connect cluster state (or null) |

### Example Usage in Dependent Modules:

```yaml
# Topic Module
inputs:
  kafka_cluster:
    type: '@facets/gcp-msk'
    # Accesses: cluster_id, location

# Connector Module  
inputs:
  kafka_cluster:
    type: '@facets/gcp-msk'
    # Accesses: connect_cluster_id, connect_cluster_location
```

## Auto-Rebalancing

The cluster automatically rebalances partitions when scaling up:

```hcl
rebalance_config {
  mode = "AUTO_REBALANCE_ON_SCALE_UP"
}
```

**Benefits:**
- ✅ Automatic partition distribution
- ✅ Improved resource utilization after scaling
- ✅ No manual intervention required

## Monitoring & Operations

### Cluster States

- `CREATING` - Cluster is being provisioned
- `ACTIVE` - Cluster is running and ready
- `DELETING` - Cluster is being deleted

### Connect Cluster States (if enabled)

- `CREATING` - Connect cluster provisioning
- `ACTIVE` - Connect cluster ready for connectors
- `DELETING` - Connect cluster being deleted

### Recommended Monitoring

1. **GCP Console**: Monitor cluster health and metrics
2. **Cloud Logging**: Review Kafka logs
3. **Cloud Monitoring**: Set up alerts for capacity
4. **Throughput Metrics**: Monitor read/write rates

## Migration & Upgrades

### Kafka Version Upgrades

To upgrade Kafka version:

```yaml
spec:
  version_config:
    kafka_version: '3.7'  # Change from '3.6' to '3.7'
```

**Notes:**
- No downtime for version upgrades
- Test in non-production first
- Review Kafka release notes

### Scaling Operations

To scale capacity:

```yaml
spec:
  sizing:
    vcpu_count: 12      # Increase from 6 to 12
    memory_gb: 24       # Increase from 12 to 24
    disk_size_gb: 1000  # Increase from 500 to 1000
```

**Important:**
- Can scale **up** anytime
- **Cannot** scale down (GCP limitation)
- Auto-rebalancing occurs after scale-up

## Troubleshooting

### Issue: Cluster creation fails

**Cause**: Insufficient subnet capacity
**Solution**: Ensure subnet has at least /22 CIDR (1024 addresses)

### Issue: Connect cluster not accessible

**Cause**: Kafka cluster DNS not resolved
**Solution**: Verify VPC network configuration and DNS settings

### Issue: KMS permission errors

**Cause**: Service account lacks KMS permissions
**Solution**: Module auto-configures IAM, check if KMS API is enabled

## Important Notes

1. **Prevent Destroy**: All resources have `prevent_destroy = true` to prevent accidental deletion
2. **KMS Keys**: KMS keys are never deleted, even when cluster is destroyed
3. **No Downsizing**: Cannot reduce vCPU, memory, or disk after creation
4. **Region Specific**: Cluster and Connect must be in same region
5. **Private Only**: No public internet access, VPC-only deployment

## Reference

- [GCP Managed Kafka Documentation](https://cloud.google.com/managed-kafka/docs)
- [Kafka Connect Documentation](https://cloud.google.com/managed-kafka/docs/connect-cluster)
- [Terraform google_managed_kafka_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/managed_kafka_cluster)
- [Terraform google_managed_kafka_connect_cluster](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/managed_kafka_connect_cluster)
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
