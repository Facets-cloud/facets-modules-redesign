# GKE Cluster with Auto-Upgrade Support

![Version](https://img.shields.io/badge/version-0.1-blue)

This module creates a production-ready Google Kubernetes Engine (GKE) cluster with automatic upgrades enabled by default and comprehensive security configurations. It provides a simplified interface for developers while maintaining enterprise-grade security and operational features.

## Environment as Dimension

This module is environment-aware and handles different deployment contexts:

- **Cluster naming**: Combines instance name with environment for uniqueness
- **Network isolation**: Uses environment-specific VPC and subnet configurations  
- **Resource labeling**: Applies environment-specific tags and labels automatically
- **Security boundaries**: Configures private clusters with environment-appropriate access controls

The `var.environment` parameter influences cluster naming, network placement, and resource tagging to ensure proper isolation between environments.

## Resources Created

This module creates the following GCP resources:

- **GKE Cluster**: Regional or zonal Kubernetes cluster with private networking
- **System Node Pool**: Managed node pool with autoscaling capabilities
- **Service Account**: Dedicated service account for node pool with minimal required permissions
- **IAM Bindings**: Role assignments for logging, monitoring, and metrics collection
- **Network Policies**: Calico-based network segmentation when enabled
- **Workload Identity**: Secure identity federation between GKE and GCP services

## Security Considerations  

The module implements several security best practices by default:

- **Private clusters**: Nodes use private IP addresses with no external connectivity by default
- **Network policies**: Calico-based microsegmentation to control pod-to-pod communication  
- **Workload Identity**: Secure service-to-service authentication without storing service account keys
- **Shielded nodes**: Integrity monitoring and secure boot enabled on all nodes
- **Minimal IAM**: Node service accounts have only the minimum required permissions
- **Master authorized networks**: API server access restricted to specified CIDR blocks
- **Automatic security updates**: Cluster and nodes receive security patches automatically

The combination of these features ensures defense-in-depth security suitable for production workloads handling sensitive data.
