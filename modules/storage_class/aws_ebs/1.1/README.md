# AWS EBS StorageClass Module

This module creates a Kubernetes StorageClass for AWS EBS (Elastic Block Store) volumes using the EBS CSI driver. It enables dynamic provisioning of persistent volumes in EKS clusters.

## Features

- **Dynamic Volume Provisioning**: Automatically creates EBS volumes when PersistentVolumeClaims are created
- **Multiple Volume Types**: Supports gp2, gp3, io1, io2, st1, and sc1 EBS volume types
- **Default StorageClass**: Option to set as the cluster's default StorageClass
- **Volume Encryption**: EBS volume encryption enabled by default
- **Volume Expansion**: Supports resizing PersistentVolumeClaims without downtime
- **Configurable Performance**: Set IOPS for io1/io2 and throughput for gp3 volumes
- **WaitForFirstConsumer Binding**: Defers volume creation until pod is scheduled for better AZ placement

## Prerequisites

- EKS cluster with EBS CSI driver addon enabled
- Kubernetes provider configured with cluster credentials

## Usage

```yaml
kind: storage_class
flavor: aws_ebs
version: '1.0'
spec:
  name: gp3
  volume_type: gp3
  is_default: true
  encrypted: true
  throughput: 125
  reclaim_policy: Delete
  volume_binding_mode: WaitForFirstConsumer
  allow_volume_expansion: true
```

## Volume Types

- **gp3** (recommended): General Purpose SSD with configurable throughput (125-1000 MB/s)
- **gp2**: Previous generation General Purpose SSD
- **io1/io2**: Provisioned IOPS SSD for I/O intensive workloads (requires `iops` parameter)
- **st1**: Throughput Optimized HDD for big data workloads
- **sc1**: Cold HDD for infrequent access

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| kubernetes_cluster | @facets/kubernetes-details | Yes | Kubernetes cluster connection details |

## Outputs

| Name | Type | Description |
|------|------|-------------|
| default | @facets/storage-class | StorageClass details including name, provisioner, and configuration |

## Spec Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| name | string | gp3 | StorageClass name |
| volume_type | string | gp3 | EBS volume type (gp2, gp3, io1, io2, st1, sc1) |
| is_default | boolean | true | Set as default StorageClass |
| encrypted | boolean | true | Enable EBS encryption |
| iops | integer | - | Provisioned IOPS (io1/io2 only) |
| throughput | integer | 125 | Throughput in MB/s (gp3 only) |
| reclaim_policy | string | Delete | PV reclaim policy (Delete or Retain) |
| volume_binding_mode | string | WaitForFirstConsumer | When to bind and provision volumes |
| allow_volume_expansion | boolean | true | Enable PVC resizing |

## Notes

- Only one StorageClass should be marked as default in a cluster
- The EBS CSI driver must be installed (usually via EKS addon)
- Volume binding mode `WaitForFirstConsumer` is recommended for multi-AZ clusters to ensure volumes are created in the same AZ as the pod
- IOPS parameter only applies to io1/io2 volume types
- Throughput parameter only applies to gp3 volume type
- Encrypted volumes use the default AWS KMS key unless specified otherwise
