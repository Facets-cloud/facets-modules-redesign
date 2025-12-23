# WireGuard Operator Module

## Overview

This module deploys the nccloud/wireguard-operator on Kubernetes, which provides Custom Resource Definitions (CRDs) for managing WireGuard VPN infrastructure. The operator enables declarative management of WireGuard VPN servers and peers through Kubernetes-native resources.

## Environment as Dimension

The module respects environment-specific configurations:
- **Namespace**: Uses environment namespace by default, can be overridden per environment
- **Node Pool**: Different node pools can be specified per environment for resource isolation
- **Resource Limits**: CPU and memory limits can be adjusted per environment based on load

## Resources Created

This module creates the following Kubernetes resources:

- **Helm Release**: Deploys the wireguard-operator chart from nccloud/charts repository
- **Operator Controller**: Manages WireGuard custom resources and reconciliation
- **CRD Definitions**: Installs `Wireguard` and `WireguardPeer` custom resource definitions
- **RBAC Resources**: Service accounts, roles, and role bindings for operator permissions
- **Webhook Configuration**: Validating and mutating webhooks for CRD validation

## What the Operator Provides

Once deployed, the operator enables:

- **Automatic Key Management**: Generates and manages WireGuard keys automatically
- **IP Address Allocation**: Assigns IP addresses to peers automatically
- **Secret Storage**: Stores keys securely in Kubernetes secrets
- **Fallback Support**: Uses wireguard-go userspace implementation if kernel module unavailable
- **Metrics Exposure**: Provides Prometheus metrics for monitoring

## Security Considerations

- The operator requires elevated permissions to manage network configurations
- Private keys are stored as Kubernetes secrets with appropriate RBAC protection
- Agent pods run with NET_ADMIN capability to configure WireGuard interfaces
- Ensure proper network policies are in place to control VPN access

## Module Configuration

Key configuration options:

- **Operator Resources**: Configure CPU/memory for the operator controller pods
- **Node Pool Integration**: Deploy operator on specific node pools with tolerations
- **Helm Chart Version**: Pin to specific operator version for stability

## Dependencies

This module requires:
- Kubernetes cluster with CRD support (v1.16+)
- Helm provider configured
- Node pool capable of running privileged containers (for WireGuard)

## Next Steps

After deploying this operator, use the `wireguard-vpn` module to create WireGuard VPN server instances using the `Wireguard` CRD.
