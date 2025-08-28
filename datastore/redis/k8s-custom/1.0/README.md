# Redis on Kubernetes (k8s-custom)

![Version](https://img.shields.io/badge/version-1.0-blue.svg)
![Cloud](https://img.shields.io/badge/cloud-kubernetes-green.svg)

## Overview

This module deploys Redis on Kubernetes using the Bitnami Helm chart with production-ready defaults and developer-friendly configuration options. It supports both standalone and replication architectures with automatic authentication, persistent storage, and backup functionality.

## Environment as Dimension

This module is environment-aware and creates unique namespaces per environment deployment. Resources are tagged with environment metadata and use the environment's unique name for resource isolation. Each environment gets its own Redis instance with separate storage, networking, and credentials.

## Resources Created

- **Kubernetes Namespace**: Dedicated namespace for Redis deployment with environment-specific naming
- **Redis Deployment**: Master/replica Redis instances deployed via Helm chart with configurable sizing
- **Persistent Storage**: Dedicated persistent volumes for Redis data with configurable storage size
- **Authentication Secret**: Kubernetes secret with auto-generated strong passwords for Redis access  
- **Network Services**: Kubernetes services for Redis master and replica endpoints with cluster DNS
- **Backup Configuration**: Automatic RDB snapshots every 6 hours with restore capability from existing backups
- **Resource Limits**: CPU and memory limits configured per instance for resource governance
- **Security Context**: Non-root user execution with read-only filesystem and dropped capabilities

## Security Considerations

All security configurations are hardcoded for production use and cannot be disabled. Redis authentication is always enabled with strong auto-generated passwords stored in Kubernetes secrets. The deployment runs with non-root security context, read-only root filesystem, and dropped Linux capabilities. Persistent storage retains data across pod restarts, and automatic backups provide data protection with 7-day retention policies.

Network policies can be enabled in clusters that support them for additional isolation. All communication within the cluster uses DNS-based service discovery with Redis AUTH protocol for authentication.

## Key Features

**Production Security**: Authentication always enabled, non-root execution, capability dropping, and read-only filesystems hardcoded for security compliance.

**High Availability**: Supports replication architecture with configurable replica count for read scaling and failure resilience.

**Resource Management**: Configurable CPU and memory limits with persistent storage sizing options from 1GB to 100GB capacity.

**Backup & Restore**: Automatic RDB snapshots with restore functionality from existing backup files for disaster recovery scenarios.

**Environment Isolation**: Each environment deployment creates isolated namespaces with unique resource naming and tagging strategies.

**Import Support**: Ability to import existing Helm releases, Kubernetes secrets, and services for migration scenarios.