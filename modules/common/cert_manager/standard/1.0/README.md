# cert_manager Module v1.0

This module deploys cert-manager for automated SSL/TLS certificate management in Kubernetes clusters using the cert-manager Helm chart v1.17.1.

## Overview

The module creates a fully configured cert-manager installation with support for automatic certificate provisioning via Let's Encrypt using HTTP-01 challenge validation.

## Nodepool Integration

The module supports integration with Kubernetes node pools through the optional `kubernetes_node_pool_details` input:

- **Tolerations**: Uses nodepool tolerations when provided
- **Node Selector**: Uses nodepool labels as node selectors to target specific node groups
- **Dedicated Scheduling**: When a nodepool is provided, all cert-manager components are scheduled on those nodes
- **HTTP01 Solver Pods**: Applies same scheduling constraints to certificate validation challenge pods

When no nodepool is provided, cert-manager will be scheduled based on Kubernetes' default scheduling behavior without any specific tolerations or node selectors.

## Resources Created

- cert-manager Helm chart deployment (controller, webhook, cainjector)
- Kubernetes namespace for cert-manager
- ClusterIssuer resources for Let's Encrypt staging and production (HTTP-01)

## Certificate Validation

The module uses HTTP-01 challenge validation:

- **HTTP-01 Validation**: Uses ingress-based HTTP challenges for domain ownership verification
- Creates `letsencrypt-staging-http01` for testing
- Creates `letsencrypt-prod-http01` for production certificates

## Inputs

### Required Inputs
- `kubernetes_details`: Kubernetes cluster connection details
- `kubernetes_node_pool_details`: Nodepool configuration for scheduling

### Optional Inputs
- `prometheus_details`: Prometheus configuration for monitoring

## Configuration Options

- **acme_email**: Custom email for ACME registration (defaults to cluster creator if not specified)
- **cert_manager**: Custom Helm chart values for cert-manager
