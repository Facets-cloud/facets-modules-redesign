# MongoDB Kubernetes Operator

## Overview

This module deploys the MongoDB Kubernetes Operator via Helm chart to manage MongoDB clusters on Kubernetes. The operator simplifies MongoDB deployment, configuration, and management using Kubernetes-native patterns and Custom Resource Definitions (CRDs).

## Environment as Dimension

The module creates resources with environment-aware naming using `var.environment.unique_name`. Resource allocation, namespace placement remain consistent across environments but can be overridden per environment if needed.

## Resources Created

- **Helm Release**: MongoDB Kubernetes Operator deployed from official MongoDB Helm chart
- **Kubernetes Namespace**: Dedicated namespace for the operator (default: `mongodb-system`)
- **Custom Resource Definitions**: MongoDBCommunity, MongoDBMulti, MongoDBOpsManager CRDs

## Node Pool Integration

The operator supports deployment to specific node pools through:

- **Node Selector**: Places operator pods on designated nodes
- **Tolerations**: Allows scheduling on nodes with matching taints

This ensures the operator runs on appropriate infrastructure while MongoDB clusters managed by the operator can be placed independently.

## Security Considerations

- Operator runs with cluster-scoped permissions to manage MongoDB CRDs across namespaces
- Resource limits prevent operator pods from consuming excessive cluster resources
- Helm atomic deployment ensures rollback on failure to maintain cluster stability
- MongoDB clusters created by this operator use secure defaults including authentication and TLS

## Dependencies

**Required:**
- Kubernetes cluster with Helm provider access

**Optional:**
- Node pool configuration for pod placement

## Outputs

The module exposes operator details for consumption by MongoDB cluster modules:
- Operator namespace and release information
- Chart version for compatibility tracking
- Deployment status and revision
