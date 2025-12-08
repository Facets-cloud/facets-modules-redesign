# GCP Managed Kafka Topic Module

This module creates and manages topics for GCP Managed Service for Apache Kafka with configurable partitions, replication, and retention policies.

## Features

- ✅ Create Kafka topics in GCP Managed Kafka clusters
- ✅ Configure partition count and replication factor
- ✅ Flexible topic configurations via `configs` parameter
- ✅ Support for all Kafka topic properties

## Usage

```yaml
kind: kafka_topic
flavor: gcp-msk
version: '1.0'
spec:
  partition_count: 3
  replication_factor: 3
  configs:
    cleanup.policy: compact
    compression.type: producer
    retention.ms: "604800000"  # 7 days
    max.message.bytes: "1048576"  # 1MB
    min.insync.replicas: "2"
```

## Configuration Parameters

### Required Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `topic_id` | string | The ID to use for the topic (e.g., 'my-topic', 'orders', 'user-events') |
| `replication_factor` | integer | Number of replicas (1-5). **3 is recommended for high availability** |

### Optional Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `partition_count` | integer | 1 | Number of partitions (1-1000). Can be increased but not decreased after creation |
| `configs` | map(string) | {} | Kafka topic configuration overrides as key-value pairs |

## Common Kafka Topic Configurations

Use the `configs` parameter to set any Kafka topic property:

### Cleanup Policy
```yaml
configs:
  cleanup.policy: "delete"  # or "compact" or "compact,delete"
```

### Compression
```yaml
configs:
  compression.type: "producer"  # or "gzip", "snappy", "lz4", "zstd", "uncompressed"
```

### Retention
```yaml
configs:
  retention.ms: "604800000"      # 7 days in milliseconds
  retention.bytes: "1073741824"  # 1GB, -1 for unlimited
```

### Message Size
```yaml
configs:
  max.message.bytes: "1048576"  # 1MB
```

### Durability
```yaml
configs:
  min.insync.replicas: "2"  # Must be <= replication_factor
```

### Segments
```yaml
configs:
  segment.ms: "604800000"      # 7 days
  segment.bytes: "1073741824"  # 1GB
```

## Complete Example

```yaml
kind: kafka
flavor: gcp-kafka_topic
version: '1.0'
spec:
  topic_id: production-orders
  partition_count: 6
  replication_factor: 3
  configs:
    cleanup.policy: "delete"
    compression.type: "lz4"
    retention.ms: "2592000000"  # 30 days
    retention.bytes: "10737418240"  # 10GB
    max.message.bytes: "2097152"  # 2MB
    min.insync.replicas: "2"
    segment.ms: "86400000"  # 1 day
```

## Input Dependencies

This module requires a GCP Managed Kafka cluster:

```yaml
inputs:
  kafka_cluster:
    type: '@facets/gcp-msk'
    description: GCP Managed Kafka cluster where the topic will be created
```

## Outputs

The module provides the following outputs:

- `topic_id` - The topic ID
- `topic_name` - Full topic name (includes project/location/cluster path)
- `cluster_id` - Parent cluster ID
- `location` - GCP location
- `partition_count` - Number of partitions
- `replication_factor` - Number of replicas
- `configs` - Applied topic configurations

## Important Notes

1. **Partition Count**: Can only be **increased**, never decreased after creation
2. **Replication Factor**: Should be set to **3** for production workloads
3. **Min In-Sync Replicas**: Must be **≤ replication_factor** (typically replication_factor - 1)
4. **Config Values**: All config values must be strings (use quotes for numbers in YAML)

## Reference

For all available Kafka topic configurations, see:
- [Apache Kafka Documentation](https://kafka.apache.org/documentation/#topicconfigs)
- [GCP Managed Kafka Topic Resource](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/managed_kafka_topic)
