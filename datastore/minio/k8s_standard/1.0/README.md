# MinIO Object Storage Module

[![KubeBlocks](https://img.shields.io/badge/KubeBlocks-v1.0-blue)](https://kubeblocks.io/)
[![MinIO](https://img.shields.io/badge/MinIO-2024--10-red)](https://min.io/)

## Overview

This module provisions and manages S3-compatible object storage clusters using MinIO on Kubernetes through the KubeBlocks operator. MinIO provides high-performance, distributed object storage with full Amazon S3 API compatibility. The module supports both standalone and distributed deployment modes with automatic high availability and horizontal scaling capabilities.

## Environment as Dimension

This module is environment-aware through the `var.environment.namespace` parameter. Each environment can have its own isolated MinIO cluster with separate credentials and storage. The module uses `var.instance_name` to create unique cluster names across environments while maintaining consistent configuration through the `spec` parameters.

## Resources Created

The module creates and manages the following Kubernetes resources:

- **KubeBlocks Cluster (MinIO)**: Primary MinIO cluster resource managed by KubeBlocks operator
- **Kubernetes Namespace**: Dedicated namespace for the MinIO cluster (if custom namespace specified)
- **Persistent Volume Claims**: Storage volumes for MinIO data (configurable volumes per server)
- **Kubernetes Services**: API service (port 9000) and Console service (port 9001)
- **Secrets**: Auto-generated root user credentials for S3 access and console login
- **StatefulSets**: Created automatically by KubeBlocks for MinIO server pods

## Deployment Modes

### Standalone Mode
Single MinIO server instance suitable for development and testing. Provides full S3 API compatibility but without high availability or data redundancy.

### Distributed Mode
Multiple MinIO servers (minimum 4, recommended even numbers) with erasure coding for data protection. Provides high availability, automatic failover, and data redundancy. Each server failure is tolerated up to N/2 servers where N is the total replica count.

## Storage Architecture

MinIO uses multiple volumes per server to maximize I/O performance and enable horizontal scaling. The module creates `volumes_per_server` persistent volumes for each replica, allowing for efficient data distribution and future capacity expansion through KubeBlocks' automated Server Pool management.

## High Availability

In distributed mode, the module automatically configures:
- Pod anti-affinity to spread MinIO servers across different nodes
- Multiple replicas with erasure coding for data redundancy
- Automatic failover and recovery
- Read-after-write consistency across all nodes

## Horizontal Scaling

KubeBlocks manages MinIO scaling by maintaining replica history and dynamically constructing Server Pool addresses. When scaling out, new nodes are added as additional Server Pools, allowing the cluster to expand while preserving existing data and maintaining availability.

## Access Methods

### S3 API Access
Connect using any S3-compatible client with the provided endpoint, access key, and secret key. The API is fully compatible with AWS S3 SDKs and tools like `aws-cli`, `s3cmd`, and `mc` (MinIO Client).

### Web Console
Access the MinIO Console through port 9001 for visual management of buckets, objects, users, and access policies. Use the root username and password from the module outputs.

## Initial Bucket Creation

The module supports automatic bucket creation during initialization through the `buckets` parameter. Provide a comma-separated list of bucket names to create them when the cluster first starts.

## Security Considerations

MinIO credentials are auto-generated and stored in Kubernetes secrets. The module marks sensitive outputs (secret_key, password) appropriately to prevent accidental exposure in logs. In production:

- Enable TLS/SSL for API and Console access
- Rotate root credentials regularly
- Use IAM policies to create limited-privilege access keys
- Restrict network access using Kubernetes NetworkPolicies
- Enable audit logging for compliance requirements

## Volume Expansion

Storage volumes can be expanded by updating the `storage.size` parameter. KubeBlocks automatically handles PVC expansion for supported storage classes. Volume size can only be increased, never decreased.

## Backup and Disaster Recovery

Consider implementing backup strategies using:
- MinIO's built-in versioning and object locking features
- External backup tools that support S3-compatible storage
- Kubernetes volume snapshots for persistent volume backups
- Cross-region replication for disaster recovery

## Performance Tuning

Optimize performance by:
- Increasing `volumes_per_server` for better I/O parallelism
- Using high-performance storage classes (SSD/NVMe)
- Allocating sufficient CPU and memory resources
- Deploying across multiple availability zones
- Tuning erasure coding settings based on your redundancy needs
