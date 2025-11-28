# MongoDB Kubernetes Operator Module

## Overview

This module deploys a MongoDB replica set on Kubernetes using the MongoDB Community Kubernetes Operator. It provides a production-ready MongoDB deployment with configurable replicas, storage, and authentication.

## Environment as Dimension

This module is environment-aware and uses `var.environment.unique_name` to ensure unique resource naming across different environments. The replica set is deployed within the environment's namespace context.

## Resources Created

- **MongoDBCommunity Custom Resource** - A custom resource managed by the MongoDB operator that defines the replica set
- **StatefulSet** - Managed by the operator for MongoDB pods with persistent storage
- **Persistent Volumes** - Separate volumes for data and logs per replica
- **Kubernetes Services** - Headless service for replica set member discovery
- **Kubernetes Secrets** - Admin user credentials with SCRAM authentication
- **ConfigMaps** - MongoDB configuration managed by the operator

## Key Features

### Replica Set Architecture
- Multi-member replica set (1-7 members)
- Automatic replica set initialization and configuration
- Member discovery via Kubernetes service
- Automatic failover and leader election

### Authentication & Security
- SCRAM authentication enabled by default
- Admin user with full cluster permissions
- Auto-generated secure passwords
- Role-based access control (clusterAdmin, userAdminAnyDatabase, readWriteAnyDatabase)

### Resource Management
- Configurable CPU and memory per pod
- Separate persistent storage for data and logs
- Data volume: Configurable size (default: 10Gi)
- Logs volume: Fixed 2Gi
- Node selector and tolerations support via node pool integration

### High Availability
- Replica set ensures data redundancy
- Automatic failover on primary failure
- Read scaling across secondary replicas
- Persistent storage for data durability

### Integration
- Integrates with Kubernetes clusters (EKS, AKS, GKE)
- Requires MongoDB Community Operator pre-installed via Helm
- Node pool integration for pod placement control

## Outputs

The module exposes the following outputs for consumption by other modules:

### Attributes
- `namespace` - Kubernetes namespace where MongoDB is deployed
- `service_name` - Headless service name for replica set
- `replica_set_name` - Name of the MongoDB replica set
- `database_name` - Default database name
- `username` - Admin username
- `password` - Auto-generated admin password (sensitive)
- `replica_count` - Number of replica set members
- `replica_hosts` - List of individual replica FQDNs
- `secrets` - List of sensitive field names

### Interfaces
- `node1` - First replica endpoint with host, port, username, password
- `node2` - Second replica endpoint with host, port, username, password
- `node3` - Third replica endpoint with host, port, username, password

## Dependencies

This module requires the following inputs:

1. **Kubernetes Cluster** (`@facets/eks`) - Target Kubernetes cluster with kubernetes and helm providers
2. **Node Pool** (`@facets/kubernetes_nodepool`) - Node pool for pod placement and resource allocation
3. **MongoDB Operator** (`@facets/helm`) - Pre-installed MongoDB Community Operator Helm release

## MongoDB Configuration

### Supported Versions
- MongoDB 7.0.15 (default)
- MongoDB 6.0.13
- MongoDB 5.0.24

### Storage Configuration
- **Data Volume**: Configurable via `storage_size` (default: 10Gi)
- **Logs Volume**: Fixed at 2Gi
- **Access Mode**: ReadWriteOnce
- **Reclaim Policy**: Based on storage class configuration

### User Roles
The admin user is created with the following roles:
- `clusterAdmin` - Full cluster administration
- `userAdminAnyDatabase` - User management on all databases
- `readWriteAnyDatabase` - Read/write access to all databases

## Security Considerations

- SCRAM authentication enabled by default for enhanced security
- Admin credentials are auto-generated and stored securely in Kubernetes secrets
- Credentials are marked as sensitive in Terraform outputs
- Role-based access control with admin having full permissions
- Communication within the replica set uses internal Kubernetes networking
- Storage is persistent but not explicitly encrypted (enable encryption at the storage class level)
- Secrets are managed by the MongoDB operator

## Version Compatibility

- Terraform: v1.5.7+
- Kubernetes: 1.21+
- MongoDB Community Operator: 0.7+
- MongoDB: 5.0.24, 6.0.13, 7.0.15
