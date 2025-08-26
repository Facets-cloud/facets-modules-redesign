# PostgreSQL on Kubernetes Module

![Version](https://img.shields.io/badge/version-1.0-blue.svg)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-13|14|15|16-blue.svg)

## Overview

This module deploys PostgreSQL database on Kubernetes using the production-ready Bitnami Helm chart. It provides configurable storage, high availability options, and secure defaults for enterprise use. The module supports both standalone and primary-replica architectures with automated backup configuration.

## Environment as Dimension

The module is **environment-aware** and provisions unique resources per environment using `var.environment.unique_name`:

- **Helm Release Names**: Each environment gets uniquely named releases to prevent conflicts
- **Storage**: Persistent volume claims are isolated per environment
- **Networking**: Services and network policies are scoped to environment-specific namespaces
- **Security**: Secrets and authentication are managed separately for each environment

## Resources Created

This module creates the following Kubernetes resources:

- **PostgreSQL StatefulSet** via Bitnami Helm chart with configurable version and resources
- **Persistent Volume Claims** for database storage with configurable size and storage class
- **Kubernetes Services** for database connectivity (primary and read replica)
- **Kubernetes Secret** containing database credentials and configuration
- **Network Policy** for secure pod-to-pod communication within namespace
- **Namespace** for isolated deployment (optional, if not using default)
- **External Service** for cluster-internal database access
- **Backup CronJob** with automated 7-day retention policy

## Architecture Support

**Standalone Mode**: Single PostgreSQL instance with persistent storage and automated backups.

**Replication Mode**: Primary-replica setup with configurable read replica count (1-5) for high availability and read scaling.

## Security Considerations

The module implements security-first defaults:

- **Encryption**: PostgreSQL connections secured with TLS
- **Network Isolation**: Network policies restrict traffic to same namespace only
- **Credential Management**: Automatic password generation stored in Kubernetes secrets
- **Backup Security**: Encrypted backup storage with retention policies
- **Resource Limits**: CPU and memory limits prevent resource exhaustion
- **High Availability**: Multi-replica support for production workloads

## Backup and Restore

**Automated Backups**: Daily backups scheduled at 2 AM with 7-day retention policy.

**Restore Support**: Module supports restoring from existing backups stored in S3, GCS, or persistent volume claims. When restoring, provide the source path and master password for the restored instance.

**Import Capability**: Existing PostgreSQL deployments can be imported by specifying Helm release name, namespace, service names, and secret references.

## Resource Management

The module follows Kubernetes best practices:

- **Resource Requests/Limits**: Configurable CPU and memory for predictable scheduling
- **Storage Classes**: Support for different storage tiers and providers
- **Lifecycle Management**: Prevents accidental destruction of persistent data
- **Monitoring Ready**: Metrics endpoint exposed for Prometheus integration