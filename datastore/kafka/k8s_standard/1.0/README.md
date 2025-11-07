# Strimzi Kafka Cluster Module

## Overview

This module deploys an Apache Kafka cluster on Kubernetes using the Strimzi Kafka Operator with KRaft mode (no ZooKeeper required). It provides a production-ready Kafka deployment with configurable brokers, storage, and authentication.

## Environment as Dimension

This module is environment-aware and uses `var.environment.unique_name` to ensure unique resource naming across different environments. The cluster is deployed within the environment's namespace context.

## Resources Created

- **Kafka Custom Resource** - A custom resource managed by the Strimzi operator that defines the Kafka cluster
- **KafkaNodePool Custom Resource** - Defines dual-role nodes (controller + broker) with KRaft mode
- **Persistent Volumes** - Persistent storage for each Kafka broker
- **Kubernetes Services** - Service endpoints for bootstrap servers (plain and TLS)
- **Kubernetes Secrets** - Admin user credentials with SCRAM-SHA-512 authentication
- **KafkaUser Custom Resource** - Admin user with full cluster permissions

## Key Features

### KRaft Mode
- No ZooKeeper dependency - uses KRaft consensus protocol
- Dual-role nodes acting as both controllers and brokers
- Simplified architecture and reduced operational overhead

### Authentication & Authorization
- SCRAM-SHA-512 authentication enabled by default
- Admin user with full cluster permissions
- Auto-generated secure passwords
- Simple ACL-based authorization

### Listeners
- Plain listener on port 9092 (optional)
- TLS listener on port 9093 (optional)
- Both listeners support SCRAM-SHA-512 authentication

### Resource Management
- Configurable CPU and memory per pod
- Configurable persistent storage per replica
- Node selector and tolerations support via node pool integration

### High Availability
- Multi-replica cluster support (1-9 replicas)
- Configurable replication factors
- Minimum in-sync replicas configuration

### Integration
- Integrates with Kubernetes clusters (EKS, AKS, GKE)
- Requires Strimzi operator pre-installed via Helm
- Node pool integration for pod placement control

## Outputs

The module exposes the following outputs for consumption by other modules:

### Attributes
- `namespace` - Kubernetes namespace where Kafka is deployed
- `cluster_name` - Name of the Kafka cluster
- `bootstrap_service` - Bootstrap service name
- `bootstrap_servers` - Full bootstrap server address
- `replica_count` - Number of broker replicas
- `broker_endpoints` - List of individual broker endpoints
- `kafka_version` - Kafka version deployed
- `admin_username` - Admin username
- `admin_password` - Auto-generated admin password (sensitive)
- `ca_cert_secret` - Name of CA certificate secret for TLS
- `secrets` - List of sensitive field names

### Interfaces
- `bootstrap` - Bootstrap server endpoint with SASL/SCRAM credentials
- `bootstrap_tls` - Bootstrap server TLS endpoint (when TLS is enabled)

## Dependencies

This module requires the following inputs:

1. **Kubernetes Cluster** (`@facets/eks`) - Target Kubernetes cluster with kubernetes and helm providers
2. **Node Pool** (`@facets/kubernetes_nodepool`) - Node pool for pod placement and resource allocation
3. **Strimzi Operator** (`@facets/helm`) - Pre-installed Strimzi Kafka operator Helm release

## Configuration

### Kafka Configuration
The module exposes key Kafka broker configurations:
- `offsets.topic.replication.factor` - Replication factor for offsets topic (default: 3)
- `transaction.state.log.replication.factor` - Transaction log replication (default: 3)
- `transaction.state.log.min.isr` - Minimum in-sync replicas for transaction log (default: 2)
- `default.replication.factor` - Default topic replication factor (default: 3)
- `min.insync.replicas` - Minimum in-sync replicas (default: 2)

## Security Considerations

- SCRAM-SHA-512 authentication enabled by default for enhanced security
- TLS encryption available for client connections
- Admin credentials are auto-generated and stored securely in Kubernetes secrets
- Credentials are marked as sensitive in Terraform outputs
- ACL-based authorization with admin user having full permissions
- CA certificates available for TLS verification
- Storage is persistent but not explicitly encrypted (enable encryption at the storage class level)

## Version Compatibility

- Terraform: v1.5.7+
- Kubernetes: 1.21+
- Strimzi Operator: 0.35+
- Apache Kafka: 4.0.0, 4.1.0 (KRaft mode)
