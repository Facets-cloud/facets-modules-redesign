# Elasticsearch ECK Operator Module

## Overview

This module deploys an Elasticsearch cluster on Kubernetes using the Elastic Cloud on Kubernetes (ECK) Operator. It provides a production-ready Elasticsearch deployment with configurable resources, storage, and node configuration.

## Environment as Dimension

This module is environment-aware and uses `var.environment.unique_name` to ensure unique resource naming across different environments. The cluster is deployed within the environment's namespace context.

## Resources Created

- **Elasticsearch Custom Resource** - A custom resource managed by the ECK operator that defines the Elasticsearch cluster
- **Persistent Volumes** - Persistent storage for each Elasticsearch node
- **Kubernetes Services** - Service endpoints for HTTP/HTTPS access
- **Kubernetes Secrets** - Auto-generated credentials for the elastic user
- **StatefulSet** - Managed by ECK operator for Elasticsearch pods

## Key Features

### Node Configuration
- Combined master+data+ingest nodes for simplified architecture
- Configurable replica count (1-9 nodes)
- Support for multiple Elasticsearch versions (7.17.x, 8.10.x, 8.11.x)

### Resource Management
- Configurable CPU and memory per pod
- Configurable persistent storage per node
- Node selector and tolerations support via node pool integration

### High Availability
- Multi-node cluster support
- Persistent storage for data durability
- TLS-enabled communication

### Integration
- Integrates with Kubernetes clusters (EKS, AKS, GKE)
- Requires ECK operator pre-installed via Helm
- Node pool integration for pod placement control

## Outputs

The module exposes the following outputs for consumption by other modules:

### Attributes
- `namespace` - Kubernetes namespace where Elasticsearch is deployed
- `cluster_name` - Name of the Elasticsearch cluster
- `elasticsearch_service` - Service name for HTTP access
- `elasticsearch_url` - Full HTTPS URL to the cluster
- `replica_count` - Number of nodes in the cluster
- `elasticsearch_version` - Elasticsearch version deployed
- `elastic_username` - Admin username (always "elastic")
- `elastic_password` - Auto-generated admin password (sensitive)
- `node_hosts` - List of individual node FQDNs
- `secrets` - List of sensitive field names

### Interfaces
- `http` - HTTP endpoint with host, port, username, password
- `https` - HTTPS endpoint with host, port, username, password
- `node1`, `node2`, `node3...` - Individual node endpoints

## Dependencies

This module requires the following inputs:

1. **Kubernetes Cluster** (`@facets/eks`) - Target Kubernetes cluster with kubernetes and helm providers
2. **Node Pool** (`@facets/aws_karpenter_nodepool`) - Node pool for pod placement and resource allocation
3. **ECK Operator** (`@facets/helm`) - Pre-installed ECK operator Helm release

## Security Considerations

- All communication is TLS-encrypted by default
- Admin credentials are auto-generated and stored securely in Kubernetes secrets
- Credentials are marked as sensitive in Terraform outputs
- Network access is controlled at the Kubernetes service level
- Storage is persistent but not explicitly encrypted (enable encryption at the storage class level)

## Version Compatibility

- Terraform: v1.5.7+
- Kubernetes: 1.21+
- ECK Operator: 2.0+
- Elasticsearch: 7.17.15, 8.10.4, 8.11.0
