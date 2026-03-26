# Kafka Strimzi Module

Apache Kafka cluster deployed using Strimzi Kafka Operator with KRaft mode (no ZooKeeper required).

## Features

- **KRaft Mode**: No ZooKeeper dependency, using Kafka's native consensus protocol
- **Dual-Role Nodes**: Controller and broker roles combined for simplified topology
- **SCRAM-SHA-512 Authentication**: Secure authentication for all listeners
- **Configurable Listeners**: Plain (port 9092) and TLS (port 9093) listeners
- **Node Pool Support**: Optional node pool targeting with taints and tolerations
- **Persistent Storage**: Configurable persistent volumes for data retention
- **Admin User**: Auto-generated admin credentials with full cluster permissions

## Requirements

- Strimzi Kafka Operator must be deployed (via `strimzi-operator` module)
- Kubernetes cluster with sufficient resources
- Optional: Node pool for workload isolation

## Configuration

### Version & Basic Configuration

- `kafka_version`: Apache Kafka version (4.0.0, 4.1.0, 3.9.0)
- `admin_username`: Admin user for authentication (default: "admin")

### Sizing & Performance

- `replica_count`: Number of Kafka broker replicas (1-9, default: 3)
- `resources.cpu`: CPU allocation (default: "1")
- `resources.memory`: Memory allocation (default: "2Gi")
- `storage_size`: Persistent volume size per replica (default: "10Gi")

### Listeners

- `plain_enabled`: Enable plain listener on port 9092 (default: true)
- `tls_enabled`: Enable TLS listener on port 9093 (default: true)

### Kafka Configuration

- `offsets_topic_replication_factor`: Offsets topic replication (default: 3)
- `transaction_state_log_replication_factor`: Transaction log replication (default: 3)
- `transaction_state_log_min_isr`: Transaction log min ISR (default: 2)
- `default_replication_factor`: Default topic replication (default: 3)
- `min_insync_replicas`: Min in-sync replicas (default: 2)

## Outputs

### Attributes

- `namespace`: Kubernetes namespace
- `cluster_name`: Kafka cluster name
- `bootstrap_service`: Bootstrap service name
- `bootstrap_servers`: Bootstrap server connection string
- `replica_count`: Number of replicas
- `broker_endpoints`: Individual broker endpoints
- `kafka_version`: Deployed Kafka version
- `admin_username`: Admin username
- `admin_password`: Admin password (sensitive)
- `ca_cert_secret`: CA certificate secret name

### Interfaces

- `cluster.endpoint`: Bootstrap endpoint
- `cluster.connection_string`: Full connection string with credentials
- `cluster.username`: Admin username
- `cluster.password`: Admin password
- `cluster.endpoints`: Individual broker endpoints map
- `cluster.secrets`: List of secret names

## Example Usage

```yaml
kind: kafka
flavor: strimzi
version: '1.0'
spec:
  version_config:
    kafka_version: '4.0.0'
    admin_username: admin
  sizing:
    replica_count: 3
    resources:
      cpu: '1'
      memory: 2Gi
    storage_size: 10Gi
  listeners:
    plain_enabled: true
    tls_enabled: true
  config:
    offsets_topic_replication_factor: 3
    transaction_state_log_replication_factor: 3
    transaction_state_log_min_isr: 2
    default_replication_factor: 3
    min_insync_replicas: 2
```

## Resources Created

- `KafkaNodePool`: Defines the node pool for dual-role Kafka brokers/controllers
- `Kafka`: Main Kafka cluster custom resource
- `KafkaUser`: Admin user with full permissions
- `Secret`: Admin password secret

## Dependencies

- Strimzi Kafka Operator (input: `strimzi_operator`)
- Kubernetes cluster connection (input: `kubernetes_cluster`)
- Optional: Kubernetes node pool (input: `node_pool`)
