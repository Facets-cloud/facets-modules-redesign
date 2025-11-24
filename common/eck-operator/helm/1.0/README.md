# ECK Operator Helm Module

![Version](https://img.shields.io/badge/version-1.0-blue)
![Cloud](https://img.shields.io/badge/cloud-kubernetes-326CE5)

## Overview

This module deploys the Elastic Cloud on Kubernetes (ECK) Operator using Helm charts. The ECK Operator automates the deployment, provisioning, management, and orchestration of Elasticsearch, Kibana, APM Server, Enterprise Search, Beats, Elastic Agent, and Elastic Maps Server on Kubernetes.

The operator simplifies Elastic Stack management by providing Kubernetes-native APIs and automated lifecycle operations including upgrades, downgrades, configuration changes, and backup/restore operations.

## Environment as Dimension

The module is **environment-aware** through the following mechanisms:

- **Namespace Management**: Can use environment-specific namespaces or a custom namespace per deployment
- **Resource Allocation**: CPU and memory limits can be adjusted per environment (development vs production)
- **Node Pool Targeting**: Optional node pool assignment allows environment-specific compute resource isolation

The `var.environment` context is used to determine default namespace behavior and can influence deployment topology based on environment requirements.

## Resources Created

This module creates the following Kubernetes resources:

- **Namespace**: Optional namespace creation for ECK Operator isolation (created only when using default namespace)
- **Helm Release**: ECK Operator deployment via Helm chart (version 2.14.0)
- **Custom Resource Definitions (CRDs)**: Kubernetes CRDs for Elasticsearch, Kibana, and other Elastic components (installed by default)
- **Operator Deployment**: Controller manager pods that watch and reconcile Elastic resources
- **Webhook Server**: Validating and mutating admission webhook for Elastic CRDs
- **RBAC Resources**: Service accounts, roles, and role bindings for operator permissions
- **Services**: Internal services for webhook communication and operator management

## Node Pool Integration

When a node pool is provided as input, the module configures:

- **Node Selector**: Ensures operator pods are scheduled on designated nodes
- **Tolerations**: Allows scheduling on tainted nodes (e.g., dedicated node pools)
- **Affinity Rules**: Enforces node placement preferences for high availability

This enables dedicated compute resources for the ECK Operator, separating it from application workloads.

## Resource Configuration

The module provides configurable resource limits for the ECK Operator pods:

- **CPU Request/Limit**: Controls CPU allocation (default: 100m request, 1 core limit)
- **Memory Request/Limit**: Controls memory allocation (default: 150Mi request, 1Gi limit)

These settings should be adjusted based on the scale of Elastic clusters being managed.

## Namespace Behavior

The module implements intelligent namespace management:

- **Custom Namespace Provided**: Uses the specified namespace (assumes it exists)
- **Empty Namespace String**: Creates and uses the default `elastic-system` namespace
- **Namespace Creation**: Only creates namespace when using the fallback default value

This prevents conflicts with existing namespace management and supports both dedicated and shared namespace scenarios.

## Security Considerations

### Operator Permissions

The ECK Operator requires cluster-level permissions to manage Elastic resources across namespaces. The Helm chart creates appropriate RBAC resources with the following capabilities:

- **Cluster-scoped**: Operator can manage Elastic resources in any namespace
- **CRD Management**: Full control over Elastic custom resources
- **Secret Access**: Read/write access to secrets for certificate management and credentials
- **Pod Management**: Create, update, and delete pods for Elastic components

### Webhook Security

The validating and mutating admission webhooks enforce security policies:

- **TLS Communication**: Webhooks use TLS certificates for secure API server communication
- **Resource Validation**: Prevents invalid Elastic resource configurations
- **Mutation Control**: Automatically applies best practices and security defaults

### Network Policies

Consider implementing Kubernetes NetworkPolicies to:
- Restrict operator pod communication to necessary services only
- Isolate webhook traffic to the Kubernetes API server
- Control egress for image pulls and external integrations

### Secrets Management

The operator creates and manages TLS certificates and credentials as Kubernetes secrets. Ensure:
- Secret encryption at rest is enabled in the cluster
- RBAC policies limit access to operator-managed secrets
- Secret rotation policies are in place for production environments

## Advanced Configuration

The module supports advanced Helm value overrides through the `helm_values` parameter. This allows customization of:

- Webhook configuration and policies
- Image pull secrets and registries
- Additional operator flags and arguments
- Telemetry and monitoring settings