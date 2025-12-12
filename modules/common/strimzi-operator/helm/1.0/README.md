# Strimzi Kafka Operator

## Overview

This module deploys the Strimzi Kafka Operator via Helm chart to manage Apache Kafka clusters on Kubernetes. Strimzi simplifies Kafka deployment, configuration, and management using Kubernetes-native patterns and Custom Resource Definitions (CRDs).

## Environment as Dimension

The module creates resources with environment-aware naming using `var.environment.unique_name`. Resource allocation, namespace placement, and watch scope remain consistent across environments but can be overridden per environment if needed.

## Resources Created

- **Helm Release**: Strimzi Kafka Operator deployed from official Helm chart
- **Kubernetes Namespace**: Dedicated namespace for the operator (default: `kafka`)
- **Custom Resource Definitions**: Kafka, KafkaConnect, KafkaTopic, KafkaUser CRDs

## Node Pool Integration

The operator supports deployment to specific node pools through:

- **Node Selector**: Places operator pods on designated nodes
- **Tolerations**: Allows scheduling on nodes with matching taints

This ensures the operator runs on appropriate infrastructure while Kafka clusters managed by the operator can be placed independently.

## Security Considerations

- Operator runs with cluster-scoped permissions to manage Kafka CRDs across namespaces
- Watch namespace configuration can limit operator scope to specific namespaces
- Resource limits prevent operator pods from consuming excessive cluster resources
- Helm atomic deployment ensures rollback on failure to maintain cluster stability

## Dependencies

**Required:**
- Kubernetes cluster with Helm provider access

**Optional:**
- Node pool configuration for pod placement

## Outputs

The module exposes operator details for consumption by Kafka cluster modules:
- Operator namespace and release information
- Chart version for compatibility tracking
- Watch namespace configuration
- Deployment status and revision
