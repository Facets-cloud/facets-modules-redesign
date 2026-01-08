# KubeBlocks Operator Module

This module deploys the KubeBlocks operator (v1.0.1) on Kubernetes with all database addons enabled by default. The operator enables declarative management of stateful database workloads including PostgreSQL, MySQL, MongoDB, Redis, and Kafka.

## Overview

KubeBlocks extends Kubernetes with Custom Resource Definitions (CRDs) that abstract database lifecycle operations. This module installs the core operator and automatically deploys all database-specific addon charts (v1.0.1) as separate Helm releases managed by Terraform.

## Environment Awareness

This module is **environment-agnostic**. The same KubeBlocks operator configuration applies across all environments (dev, staging, production). Environment-specific database configurations are handled by individual database cluster modules that consume this operator.

The module uses `var.environment.cloud_tags` to tag Kubernetes namespace resources for control plane traceability.

## Resources Created

- **Kubernetes Namespace**: `kb-system` namespace with metadata labels and CRD dependency tracking
- **KubeBlocks Operator**: Helm release installing the core operator controllers and webhooks
- **Database Addon Helm Releases**: Separate releases for all database types (PostgreSQL, MySQL, MongoDB, Redis, Kafka) - automatically installed
- **Dependency Outputs**: Release IDs and status indicators for other modules to coordinate installation order

## Database Addons

The module automatically installs all database addon charts that provide ComponentDefinitions and ClusterDefinitions. Each addon is deployed as an independent Helm release (v1.0.1):

### Available Addons

- **PostgreSQL** (v1.0.1): ComponentDefinitions for PostgreSQL 12-16 with standalone and replication topologies
- **MySQL** (v1.0.1): ComponentDefinitions for MySQL 5.7, 8.0, 8.4 with standalone and replication modes
- **MongoDB** (v1.0.1): ComponentDefinitions for MongoDB 4.0-7.0 with standalone, replication set, and sharded cluster support
- **Redis** (v1.0.1): ComponentDefinitions for Redis 5-8 with standalone, replication (Sentinel), and cluster modes
- **Kafka** (v1.0.1): ComponentDefinitions for Kafka with KRaft and ZooKeeper-based deployments

### Addon Installation

All database addons are automatically enabled and installed by default. Each addon creates a separate Helm release:
- Release name: `kb-addon-<database>`
- Namespace: `kb-system`
- Chart version: `1.0.1`
- Repository: `https://apecloud.github.io/helm-charts`

Addons install the following resources:
- **ComponentDefinitions**: Versioned definitions (e.g., `redis-7-1.0.1`, `postgresql-14-1.0.1`)
- **ClusterDefinitions**: Topology definitions (e.g., `redis`, `postgresql`)
- **ConfigMaps**: Default configuration templates for each database version
- **Backup Policy Templates**: Data protection configurations

## Architecture

The module follows a layered architecture:

1. **CRD Module** (`kubeblocks-crd`): Installs 40+ CRDs as separate Kubernetes manifests
2. **Operator Module** (this module): Deploys operator controllers with addon controller disabled
3. **Database Cluster Modules**: Consume operator output and deploy database clusters using installed addons

The addon controller is explicitly disabled (`addonController.enabled = false`) to prevent webhook-created cluster-scoped Addon CRs that would block namespace deletion during destroy operations.

## Deployment

```
┌───────────────────────┐
│   kubeblocks-crd      │
│  (Terraform Module)   │
└───────────┬───────────┘
            │
            ▼
┌────────────────────────┐
│  kubeblocks-operator   │
│   (Terraform Module)   │
└────────────────────────┘
```
** Deployment sequence:
1. Creates `kb-system` namespace with dependency annotations
2. Installs KubeBlocks operator (v1.0.1) via Helm with CRD installation skipped. CRD's are installed using a separate module.
3. Waits 2 minutes for operator controllers to stabilize
4. Installs all database addon Helm releases (PostgreSQL, MySQL, MongoDB, Redis, Kafka) sequentially

## Destruction Workflow

The module is designed for clean teardown without manual intervention when addon controller is disabled.

### Automatic Cleanup (Default Behavior)

When `addonController.enabled = false` (default):

```bash
terraform destroy
```

Terraform handles cleanup automatically:
1. Deletes all database addon Helm releases (PostgreSQL, MySQL, MongoDB, Redis, Kafka) - removes ComponentDefinitions and ClusterDefinitions
2. Removes KubeBlocks operator Helm release
3. Deletes `kb-system` namespace

**No manual cleanup required** - the namespace deletion timeout (10 minutes) allows sufficient time for all resources to be removed.

## Security Considerations

### Resource Access

- Operator requires cluster-admin privileges to create and manage CRDs and cluster-scoped resources
- Service accounts created with role bindings for controller and dataprotection managers
- Webhooks require mutating and validating admission controller access

### Network Policies

- Operator webhooks listen on port 9443 (TLS-secured)
- No default NetworkPolicy restrictions - apply policies based on organizational requirements

### Secret Management

- Database credentials auto-generated by operator and stored in Kubernetes Secrets
- Backup credentials managed through BackupRepo resources with external secret provider support

### Image Security

- Default pull policy: `IfNotPresent` (use cached images when available)
- No ImagePullSecrets configured - use private registry authentication if required
- All images pulled from official ApeCloud registry

## Configuration

### Feature Gates

Enable experimental features:

```yaml
spec:
  feature_gates:
    in_place_pod_vertical_scaling: true  # Allow CPU/memory changes without pod restart
```

### Resource Limits

Configure operator controller resource allocation:

```yaml
spec:
  resources:
    cpu_limit: 1000m      # Maximum CPU (default)
    memory_limit: 1Gi     # Maximum memory (default)
    cpu_request: 500m     # Requested CPU (default)
    memory_request: 512Mi # Requested memory (default)
```

### Data Protection

The data protection controller is enabled by default and includes:
- Spot instance tolerance for backup/restore pods
- MongoDB node tolerance for co-location scenarios
- Backup schedule management

## Module Outputs

### Attributes

- `namespace`: KubeBlocks namespace name (kb-system)
- `version`: Installed operator version
- `chart_version`: Helm chart version deployed
- `release_name`: Helm release name (kubeblocks)
- `release_status`: Current Helm release status
- `crd_dependency`: CRD module release ID for dependency tracking

### Interfaces

- `output.release_id`: Unique Helm release ID for dependency chaining
- `output.release_status`: Status string for readiness checks
- `output.ready`: Readiness indicator (matches release_status)
- `output.dependency_id`: Combined release and namespace UID for strict dependency enforcement

## Technical Details

- **KubeBlocks Version**: v1.0.1
- **Addon Chart Versions**: 1.0.1 (all databases)
- **Helm Repository**: https://apecloud.github.io/helm-charts
- **Namespace**: kb-system
- **Operator Timeout**: 10 minutes
- **Addon Timeout**: 10 minutes per addon
- **Namespace Deletion Timeout**: 10 minutes
- **Post-Install Wait**: 2 minutes for operator stabilization

## ComponentDefinition Naming Convention

Addons follow a consistent naming pattern:
- Format: `<database>-<major_version>-<addon_version>`
- Examples:
  - `redis-7-1.0.1` (Redis v7.x with addon v1.0.1)
  - `postgresql-14-1.0.1` (PostgreSQL v14.x with addon v1.0.1)
  - `mongodb-6-1.0.1` (MongoDB v6.x with addon v1.0.1)

## References

- [KubeBlocks Documentation](https://kubeblocks.io/)
- [KubeBlocks GitHub](https://github.com/apecloud/kubeblocks)
- [KubeBlocks Helm Charts](https://github.com/apecloud/helm-charts)
- [KubeBlocks API Reference](https://kubeblocks.io/docs/api-docs/overview)
