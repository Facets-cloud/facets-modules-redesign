# Kafka on Kubernetes

[![Version](https://img.shields.io/badge/version-1.0-blue.svg)](./facets.yaml)
[![Flavor](https://img.shields.io/badge/flavor-k8s--custom-green.svg)](./facets.yaml)

## Overview

This module deploys Apache Kafka cluster on Kubernetes using Helm charts. It provides a developer-friendly abstraction for running Kafka workloads with secure defaults, persistent storage, and standardized connection interfaces in the default namespace.

## Environment as Dimension

The module is environment-aware and uses `var.environment.unique_name` to ensure resource uniqueness across environments. Different environments will have isolated Kafka clusters with environment-specific naming and tagging, all deployed in the default namespace.

## Resources Created

- **Kafka Cluster**: Multi-broker Kafka deployment with configurable replica count
- **Zookeeper Ensemble**: Required coordination service with 3-node setup  
- **Persistent Volumes**: Storage for Kafka data and logs (when persistence enabled)
- **Authentication Secret**: Secure credential management for Kafka access in default namespace
- **Service Resources**: ClusterIP services for internal cluster communication
- **Helm Release**: Managed deployment using Bitnami Kafka chart in default namespace

## Security Considerations

The module implements several security best practices:

- **Authentication**: SASL/PLAIN authentication enabled by default with generated passwords
- **Secret Management**: Credentials stored in Kubernetes secrets with proper labeling
- **Network Security**: ClusterIP services limit exposure to cluster-internal traffic
- **Resource Isolation**: Resources deployed in default namespace with unique naming per environment
- **Data Protection**: Persistent volumes with lifecycle protection prevent accidental data loss

## Key Features

**Version Management**: Supports the latest 3 major Kafka versions (2.8, 3.4, 3.6) with automatic defaults to the most recent stable release.

**Flexible Sizing**: Configure cluster size (1-10 brokers), storage allocation, and resource limits based on workload requirements.

**Backup & Restore**: Built-in support for restoring from existing backups with configurable source locations.

**Import Support**: Seamlessly import existing Helm-deployed Kafka clusters into Facets management.

**Monitoring Ready**: JMX and metrics endpoints enabled for integration with monitoring systems.

**Default Namespace Deployment**: Resources are deployed in the default namespace with environment-specific unique naming to ensure isolation.

The module follows Facets datastore conventions with standardized interfaces, making it compatible with other modules that consume Kafka services. All security configurations use production-ready defaults while maintaining the flexibility developers need for their specific use cases.