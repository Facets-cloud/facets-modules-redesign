# SnapScheduler Operator

![Version](https://img.shields.io/badge/version-1.0-blue)
![Cloud](https://img.shields.io/badge/cloud-kubernetes-326CE5)

## Overview

This module deploys the SnapScheduler operator using Helm charts. SnapScheduler provides automated backup and snapshot scheduling for Kubernetes persistent volumes using the Kubernetes CSI (Container Storage Interface) snapshot API. It enables declarative, schedule-based volume snapshot management through Kubernetes-native Custom Resource Definitions (CRDs).

The operator automates the creation, retention, and cleanup of persistent volume snapshots, making it easy to implement backup policies and disaster recovery strategies for stateful workloads on Kubernetes.

## Environment as Dimension

The module is **environment-aware** through the following mechanisms:

- **Namespace Management**: Can use environment-specific namespaces or a custom namespace per deployment
- **Resource Allocation**: CPU and memory limits/requests can be adjusted per environment (development vs production)
- **Node Pool Targeting**: Optional node pool assignment allows environment-specific compute resource isolation
- **Helm Release Management**: Supports atomic deployments, wait conditions, and timeout configurations per environment

The `var.environment` context is used to determine default namespace behavior and can influence deployment topology based on environment requirements.

## Resources Created

This module creates the following Kubernetes resources:

- **Namespace**: Optional namespace creation for SnapScheduler isolation (default: `default`)
- **Helm Release**: SnapScheduler operator deployment via Helm chart (version 3.2.0)
- **Custom Resource Definitions (CRDs)**: Kubernetes CRDs for SnapshotSchedule resources
- **Operator Deployment**: Controller manager pods that watch and reconcile snapshot schedules
- **RBAC Resources**: Service accounts, cluster roles, and cluster role bindings for operator permissions
- **Services**: Internal services for operator management and Prometheus metrics (if enabled)

## Node Pool Integration

When a node pool is provided as input, the module configures:

- **Node Selector**: Ensures operator pods are scheduled on designated nodes matching the node pool's selector
- **Tolerations**: Allows scheduling on tainted nodes (e.g., dedicated node pools for infrastructure workloads)

This enables dedicated compute resources for the SnapScheduler operator, separating it from application workloads and ensuring consistent scheduling behavior.

## Resource Configuration

The module provides granular resource control for the SnapScheduler operator pods:

- **CPU Request**: Minimum CPU allocation (default: `10m`)
- **CPU Limit**: Maximum CPU allocation (default: `1`)
- **Memory Request**: Minimum memory allocation (default: `100Mi`)
- **Memory Limit**: Maximum memory allocation (default: `1Gi`)

These settings should be adjusted based on:
- Number of snapshot schedules being managed
- Frequency of snapshot operations
- Size and count of volumes being snapshotted
- Environment-specific resource constraints

## Namespace Behavior

The module implements intelligent namespace management:

- **Custom Namespace Provided**: Uses the specified namespace from `spec.namespace`
- **Environment Namespace**: Falls back to `var.environment.namespace` if available
- **Default Namespace**: Uses `default` namespace if no custom namespace is specified
- **Namespace Creation**: Controlled by `create_namespace` flag (default: `true`)

This prevents conflicts with existing namespace management and supports both dedicated and shared namespace scenarios.

## Prometheus Integration

The module supports optional Prometheus integration for metrics collection:

- **Automatic Discovery**: When `prometheus_details` input is provided, the operator is configured with the Prometheus release ID
- **Metrics Exposure**: SnapScheduler exposes metrics about snapshot operations, schedules, and status
- **ServiceMonitor**: Prometheus operator can automatically discover and scrape SnapScheduler metrics

## Helm Release Configuration

The module supports comprehensive Helm release lifecycle management:

- **Wait**: Wait for all resources to become ready before marking release as successful (default: `true`)
- **Atomic**: If installation fails, automatically purge the release (default: `false`)
- **Timeout**: Maximum time to wait for Kubernetes operations (default: `600` seconds)
- **Recreate Pods**: Force pod recreation on updates (default: `false`)
- **Cleanup on Fail**: Remove resources on failed installation (always enabled)

## Security Considerations

### Operator Permissions

The SnapScheduler operator requires specific cluster permissions:

- **VolumeSnapshot API**: Full control over VolumeSnapshot and VolumeSnapshotContent resources
- **PersistentVolumeClaim Access**: Read access to PVCs for snapshot source detection
- **Namespace-scoped**: Operator typically manages snapshots in specific namespaces
- **RBAC Resources**: ClusterRole and ClusterRoleBinding for snapshot management

### CSI Driver Requirements

SnapScheduler requires:
- CSI driver with snapshot support (e.g., AWS EBS CSI, GCP PD CSI, Azure Disk CSI)
- VolumeSnapshotClass configured in the cluster
- Snapshot controller running in the cluster (usually installed by default)

## Advanced Configuration

The module supports advanced Helm value overrides through the `helm_values` parameter. This allows customization of:

- Snapshot schedule templates and defaults
- Image registry and tag overrides
- Additional controller flags and arguments
- Logging levels and output formats
- Metrics and monitoring configuration
- RBAC scope and permissions

Example:
```yaml
helm_values:
  logLevel: debug
  replicaCount: 2
  snapshotRetention:
    defaultPolicy: "7d"
```

## Dependencies

**Required:**
- Kubernetes cluster with Helm provider access
- CSI driver with snapshot support
- VolumeSnapshot CRDs (Kubernetes 1.20+)

**Optional:**
- Prometheus instance for metrics collection
- Node pool configuration for pod placement

## Outputs

The module exposes the following outputs:

- **release_name**: Helm release name
- **namespace**: Deployment namespace
- **chart**: Chart name used for deployment
- **version**: Chart version deployed
- **status**: Current release status

## Usage Notes

- SnapScheduler uses the CSI snapshot API, which requires a CSI driver that supports snapshots
- Snapshot storage location and retention policies are controlled by VolumeSnapshotClass and SnapshotSchedule CRDs
- The operator watches for SnapshotSchedule resources and creates VolumeSnapshots based on the defined schedule
- Snapshot lifecycle (creation, retention, deletion) is fully automated once schedules are defined
