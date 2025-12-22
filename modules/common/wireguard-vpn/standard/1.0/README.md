# WireGuard VPN Server Module

[![Version](https://img.shields.io/badge/version-1.0-blue.svg)](https://github.com/facets/wireguard-vpn)

## Overview

This module deploys a WireGuard VPN server as a Kubernetes custom resource. It requires the WireGuard Resource to be installed in the cluster and creates a `Wireguard` CRD instance to provision the VPN infrastructure.

The module provides a declarative way to configure and deploy WireGuard VPN servers with cloud-specific optimizations for AWS, Azure, and GCP.

## Environment as Dimension

The module is environment-aware and adapts its behavior based on the target cloud platform:

- **Namespace**: Uses the environment namespace by default when not explicitly specified
- **Cloud Tags**: Applies environment-specific tags to all created resources
- **Service Annotations**: Automatically configures cloud-specific load balancer annotations
  - AWS: External NLB with IP target type
  - Azure: Public load balancer configuration
  - GCP: Optimized MTU settings (1380)

## Resources Created

- **Wireguard Custom Resource**: A Kubernetes CRD managed by the WireGuard Resource that provisions:
  - VPN server pods with IP forwarding enabled
  - Service with cloud-specific load balancer configuration
  - Network policies for secure VPN access
  - ConfigMaps for WireGuard configuration

## Dependencies

- **WireGuard**: Must be installed via the `wireguard` module before deploying this resource
- **Kubernetes Cluster**: Target cluster with CRD support
- **Node Pool**: Dedicated or shared node pool for VPN workloads

## Configuration

### Required Inputs

- `kubernetes_details`: Target Kubernetes cluster connection details
- `node_pool`: Node pool configuration for pod placement
- `wireguard`: Reference to the installed WireGuard Resource

### Key Parameters

- **namespace**: Deployment namespace (defaults to environment namespace)
- **enable_ip_forward**: Enable IP forwarding for VPN traffic (default: true)
- **mtu**: Maximum transmission unit size (default: 1500, recommend 1380 for GCP)
- **service_annotations**: Custom annotations for the VPN service

## Security Considerations

- IP forwarding is enabled on pods to allow VPN traffic routing
- Service is exposed via cloud load balancers with internet-facing configuration
- Node selectors and tolerations ensure pods run on designated infrastructure
- Network policies should be configured to restrict access to VPN endpoints

## Cloud-Specific Behavior

### AWS
- Uses Network Load Balancer (NLB) in external mode
- Configures IP target type for direct pod access
- Enables internet-facing scheme

### Azure
- Configures public load balancer
- Disables internal load balancer mode

### GCP
- Sets MTU to 1380 to prevent packet fragmentation
- Uses standard load balancer configuration

## Decoupled Architecture

This module is part of a two-tier architecture:
1. **WireGuard** (`wireguard` module): Installs the Resource
2. **WireGuard VPN Server** (this module): Deploys VPN instances using the Wireguard Resource

This separation allows multiple VPN servers to be managed by a single resource instance.
