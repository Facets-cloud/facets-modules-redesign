# snapshot_schedule Module v1.0

This module creates Kubernetes VolumeSnapshotClass and SnapshotSchedule resources for automated volume snapshot management using the snapscheduler.backube operator.

## Overview

The module provides automated, scheduled backups for Kubernetes persistent volumes (PVCs) with configurable retention policies. It creates two key resources:

1. **VolumeSnapshotClass**: Defines the CSI driver and parameters for creating volume snapshots
2. **SnapshotSchedule**: Configures the schedule, retention, and PVC selector for automated snapshots

## Features

- **Automated Scheduling**: Cron-based snapshot scheduling (default: every 30 minutes)
- **Cloud-Aware**: Auto-detects CSI driver based on cloud provider (AWS EBS, GCP PD, Azure Disk)
- **Flexible Retention**: Configure expiration time and maximum snapshot count
- **Label-Based Selection**: Target specific PVCs using label selectors
- **Multi-Cloud Support**: Works across AWS, GCP, and Azure Kubernetes clusters
- **Customizable Tagging**: Add custom tags, labels, and annotations to snapshots

## Prerequisites

The **snapscheduler.backube** operator must be installed in your Kubernetes cluster before deploying this module. The operator manages the SnapshotSchedule CRD and creates snapshots according to the schedule.

Additionally, ensure your cluster has the appropriate CSI snapshot controller and CSI driver installed:
- **AWS**: EBS CSI Driver (`ebs.csi.aws.com`)
- **GCP**: GCE PD CSI Driver (`pd.csi.storage.gke.io`)
- **Azure**: Azure Disk CSI Driver (`disk.csi.azure.com`)

## Resources Created

- **VolumeSnapshotClass**: CSI-backed snapshot class for volume snapshots
- **SnapshotSchedule**: CronJob-based schedule for automated snapshot creation

## How It Works

1. The module creates a VolumeSnapshotClass with cloud-specific CSI driver configuration
2. A SnapshotSchedule resource is created with:
   - Cron schedule for snapshot timing
   - Label selector to match target PVCs
   - Retention policy for snapshot lifecycle management
3. The snapscheduler operator watches SnapshotSchedule resources and creates VolumeSnapshot objects on schedule
4. The CSI driver creates the actual cloud provider snapshots (EBS snapshots, GCP snapshots, Azure snapshots)
5. Old snapshots are automatically cleaned up based on retention policy

## PVC Label Matching

The module uses label selectors to identify which PVCs to snapshot. By default, it matches:

- **resource_type label**: Targets PVCs with the `resource_type` label matching the configured value
- **instance_name label**: If `resource_name` is specified, matches PVCs with that instance name

You can add additional label selectors via `additional_claim_selector_labels` to further refine PVC targeting.

## Inputs

### Required Inputs

| Input | Type | Description |
|-------|------|-------------|
| `kubernetes_details` | `@facets/kubernetes-details` | Kubernetes cluster connection details and cloud provider information |

### Optional Configuration (spec)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `name` | string | instance_name | Custom name for the snapshot schedule |
| `namespace` | string | `"default"` | Kubernetes namespace for resources |
| `schedule` | string | `"*/30 * * * *"` | Cron expression (every 30 minutes by default) |
| `retention_policy.expires` | string | `"168h"` | Snapshot expiration time (7 days by default) |
| `retention_policy.max_count` | number | `10` | Maximum number of snapshots to retain |
| `deletionPolicy` | string | `"Delete"` | Snapshot deletion policy: `Delete` or `Retain` |
| `driver` | string | auto-detected | CSI driver override (auto-detected from cloud_provider if not set) |
| `resource_name` | string | instance_name | Resource name for PVC label matching |
| `resource_type` | string | `"snapshot_schedule"` | Resource type for PVC label matching |
| `snapshot_tags` | map(string) | `{}` | Additional cloud provider tags for snapshots |
| `labels` | map(string) | `{}` | Additional Kubernetes labels for resources |
| `annotations` | map(string) | `{}` | Additional Kubernetes annotations |
| `snapshot_template_labels` | map(string) | `{}` | Labels applied to created VolumeSnapshot objects |
| `additional_claim_selector_labels` | map(string) | `{}` | Extra label selectors for PVC matching |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `default` | `@facets/k8s_resource` | Resource name and namespace information |

## Configuration Examples

### Basic Configuration (Every 30 Minutes)

```yaml
kind: snapshot_schedule
flavor: standard
version: "1.0"
spec:
  namespace: "production"
  schedule: "*/30 * * * *"
```

### Daily Snapshots with 30-Day Retention

```yaml
kind: snapshot_schedule
flavor: standard
version: "1.0"
spec:
  namespace: "production"
  schedule: "0 2 * * *"  # 2 AM daily
  retention_policy:
    expires: "720h"      # 30 days
    max_count: 30
```

### Hourly Snapshots for Database PVCs

```yaml
kind: snapshot_schedule
flavor: standard
version: "1.0"
spec:
  namespace: "databases"
  schedule: "0 * * * *"  # Top of every hour
  resource_type: "postgres"
  additional_claim_selector_labels:
    app: "postgresql"
    tier: "database"
  retention_policy:
    expires: "168h"
    max_count: 168       # Keep 1 week of hourly snapshots
```

### Snapshots with Custom Tags and Retain Policy

```yaml
kind: snapshot_schedule
flavor: standard
version: "1.0"
spec:
  namespace: "production"
  deletionPolicy: "Retain"  # Keep snapshots even if schedule is deleted
  snapshot_tags:
    environment: "production"
    backup_type: "automated"
    compliance: "required"
  snapshot_template_labels:
    backup: "automated"
    retention: "long-term"
```

### Explicit CSI Driver Configuration

```yaml
kind: snapshot_schedule
flavor: standard
version: "1.0"
spec:
  namespace: "default"
  driver: "ebs.csi.aws.com"  # Explicitly set for AWS EBS
  schedule: "0 */6 * * *"    # Every 6 hours
```

## Cron Schedule Examples

| Schedule | Description |
|----------|-------------|
| `*/30 * * * *` | Every 30 minutes |
| `0 * * * *` | Every hour at minute 0 |
| `0 */6 * * *` | Every 6 hours |
| `0 2 * * *` | Daily at 2:00 AM |
| `0 2 * * 0` | Weekly on Sunday at 2:00 AM |
| `0 0 1 * *` | Monthly on the 1st at midnight |

## Retention Policy

The retention policy controls snapshot lifecycle:

- **expires**: Duration string (e.g., `"168h"` for 7 days, `"720h"` for 30 days)
- **max_count**: Maximum number of snapshots to keep (older snapshots deleted first)

Snapshots are deleted when EITHER condition is met (expiration OR max count exceeded).

## Snapshot Tags vs Labels

- **snapshot_tags**: Cloud provider-specific tags (AWS tags, GCP labels, Azure tags) applied to the underlying storage snapshots
- **labels**: Kubernetes labels applied to VolumeSnapshotClass and SnapshotSchedule resources
- **snapshot_template_labels**: Kubernetes labels applied to individual VolumeSnapshot objects created by the schedule

## Cloud Provider Behavior

### AWS (EBS)
- Creates EBS snapshots in the same region as the volume
- Tags are applied as EBS snapshot tags
- Snapshots are incremental (only changed blocks stored)

### GCP (Persistent Disk)
- Creates persistent disk snapshots
- Labels are applied as GCP resource labels
- Snapshots are incremental

### Azure (Managed Disk)
- Creates managed disk snapshots
- Tags are applied as Azure resource tags
- Snapshots can be incremental or full depending on disk type

## Important Notes

1. **Operator Dependency**: The snapscheduler.backube operator must be installed and running
2. **CSI Driver**: Ensure the appropriate CSI snapshot controller is installed for your cloud provider
3. **Storage Class**: PVCs must use a StorageClass that supports volume snapshots
4. **Permissions**: The operator service account needs permissions to create VolumeSnapshot resources
5. **Costs**: Snapshots incur storage costs on your cloud provider
6. **Cross-Region**: Snapshots are typically region-specific; cross-region replication requires additional configuration

## Troubleshooting

### Snapshots Not Being Created

1. Verify snapscheduler operator is running: `kubectl get pods -n snapscheduler-system`
2. Check SnapshotSchedule status: `kubectl describe snapshotschedule <name> -n <namespace>`
3. Verify PVC label selectors match: `kubectl get pvc -n <namespace> --show-labels`
4. Check operator logs: `kubectl logs -n snapscheduler-system -l app=snapscheduler`

### Snapshots Failing

1. Verify CSI driver is installed: `kubectl get csidriver`
2. Check VolumeSnapshotClass exists: `kubectl get volumesnapshotclass`
3. Ensure StorageClass supports snapshots: `kubectl get storageclass <name> -o yaml`
4. Review VolumeSnapshot events: `kubectl describe volumesnapshot -n <namespace>`

## References

- [snapscheduler.backube Documentation](https://backube.github.io/snapscheduler/)
- [Kubernetes Volume Snapshots](https://kubernetes.io/docs/concepts/storage/volume-snapshots/)
- [AWS EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver)
- [GCP PD CSI Driver](https://github.com/kubernetes-sigs/gcp-compute-persistent-disk-csi-driver)
- [Azure Disk CSI Driver](https://github.com/kubernetes-sigs/azuredisk-csi-driver)
