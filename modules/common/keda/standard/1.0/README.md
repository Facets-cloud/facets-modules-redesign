# KEDA Module v1.0

This module deploys KEDA (Kubernetes Event-Driven Autoscaling) in Kubernetes clusters using the official KEDA Helm chart.

## Overview

The module creates a fully configured KEDA installation that enables event-driven autoscaling for Kubernetes workloads. KEDA allows you to scale applications based on external event sources and metrics, including message queues, databases, cloud services, and custom metrics from Prometheus. The module integrates with Kubernetes nodepool configurations to ensure proper scheduling of the KEDA operator on designated nodes.

## What is KEDA?

KEDA is a Kubernetes-based Event Driven Autoscaler that extends Kubernetes' Horizontal Pod Autoscaler (HPA) to support scaling based on external event sources. It acts as a metrics server and can activate or deactivate Kubernetes deployments based on events from various sources like:

- Message queues (Kafka, RabbitMQ, Azure Service Bus, etc.)
- Databases (PostgreSQL, MySQL, MongoDB, etc.)
- Cloud services (AWS SQS, Azure Event Hubs, GCP Pub/Sub, etc.)
- Prometheus metrics
- HTTP endpoints
- And many more scalers

## Environment as Dimension

This module adapts to different cloud environments:

- **AWS**: Deploys KEDA operator with support for AWS-based event sources (SQS, CloudWatch, etc.)
- **Azure**: Integrates with Azure services like Event Hubs, Service Bus, and Application Insights
- **GCP**: Supports GCP services like Pub/Sub and Cloud Monitoring
- **Kubernetes**: Works on any Kubernetes cluster with support for various event sources

The module is cloud-agnostic but can leverage cloud-specific scalers when deployed in specific environments.

## Nodepool Integration

The module supports integration with Kubernetes node pools through the optional `kubernetes_node_pool_details` input:

- **Tolerations**: Uses nodepool taints as pod tolerations to allow scheduling on tainted nodes
- **Node Selector**: Uses nodepool labels as node selectors to target specific node groups
- **Dedicated Scheduling**: When a nodepool is provided, the KEDA operator is scheduled exclusively on those nodes

When no nodepool is provided, KEDA components will be scheduled based on Kubernetes' default scheduling behavior without any specific tolerations or node selectors.

## Resources Created

- KEDA operator deployment via Helm chart
- KEDA metrics server for exposing external metrics
- Custom Resource Definitions (CRDs) for ScaledObject and ScaledJob
- RBAC resources (ServiceAccount, ClusterRole, ClusterRoleBinding)
- Webhook configurations for admission control
- Service for metrics API

## Prometheus Integration

The module supports optional integration with Prometheus for metrics-based scaling:

- When `prometheus_details` input is provided, the Prometheus helm release ID is passed to KEDA
- Enables the use of Prometheus scaler in ScaledObjects
- Allows scaling based on custom Prometheus queries and metrics

## Security Considerations

- Creates minimal RBAC permissions required for KEDA operation
- Deploys in dedicated `keda` namespace for isolation
- Supports custom security contexts via `custom_values`
- Webhook admission control for validating ScaledObject resources
- Service account-based authentication for Kubernetes API access

## Inputs

### Required Inputs

- `kubernetes_details`: Kubernetes cluster connection details and providers (type: `@facets/kubernetes-details`)
- `kubernetes_node_pool_details`: Nodepool configuration for dedicated node scheduling (type: `@facets/kubernetes_nodepool`)

### Optional Inputs

- `prometheus_details`: Prometheus instance for metrics-based scaling integration (type: `@facets/prometheus`)

## Spec Configuration

### Chart Version

- **chart_version** (string, default: `"2.9.4"`): KEDA Helm chart version to deploy

### Resource Sizing

The `size` object configures resource allocation for the KEDA operator. When set, the same value is applied to both requests and limits:

- **size.cpu** (string): CPU allocation for the KEDA operator
  - Example: `"100m"` (100 millicores), `"1"` (1 CPU core)
  - Default request: `"100m"`, Default limit: `"1"`

- **size.memory** (string): Memory allocation for the KEDA operator
  - Example: `"100Mi"` (100 mebibytes), `"1Gi"` (1 gibibyte)
  - Default request: `"100m"`, Default limit: `"1000Mi"`

### Custom Values

- **custom_values** (object, default: `{}`): Additional Helm values to pass to the KEDA chart
  - Merged last with highest priority
  - Use YAML editor in UI for complex configurations
  - Allows customization of any KEDA Helm chart value

## Outputs

The module provides the following outputs:

### Attributes

- **id**: Unique identifier for the KEDA Helm release
- **release_name**: Helm release name (typically `"keda"`)
- **namespace**: Kubernetes namespace where KEDA is deployed (default: `"keda"`)
- **chart_version**: Installed KEDA Helm chart version
- **release_status**: Status of the Helm release (e.g., `"deployed"`)

### Interfaces

No interfaces are exposed by this module.

## Example Usage

### Basic Deployment

```yaml
kind: keda
flavor: fourkites_keda
version: "1.0"
spec:
  chart_version: "2.9.4"
```

### With Custom Resource Sizing

```yaml
kind: keda
flavor: fourkites_keda
version: "1.0"
spec:
  chart_version: "2.9.4"
  size:
    cpu: "200m"
    memory: "256Mi"
```

### With Prometheus Integration

```yaml
kind: keda
flavor: fourkites_keda
version: "1.0"
spec:
  chart_version: "2.9.4"
  size:
    cpu: "200m"
    memory: "256Mi"
  custom_values:
    prometheus:
      metricServer:
        enabled: true
```

### With Custom Helm Values

```yaml
kind: keda
flavor: fourkites_keda
version: "1.0"
spec:
  chart_version: "2.9.4"
  custom_values:
    podSecurityContext:
      runAsUser: 1000
      fsGroup: 1000
    resources:
      operator:
        limits:
          cpu: 500m
          memory: 512Mi
```

## Using KEDA for Autoscaling

After deploying KEDA, you can create ScaledObject resources to enable event-driven autoscaling for your workloads:

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: my-app-scaler
  namespace: default
spec:
  scaleTargetRef:
    name: my-app-deployment
  minReplicaCount: 1
  maxReplicaCount: 10
  triggers:
  - type: prometheus
    metadata:
      serverAddress: http://prometheus-server:9090
      metricName: http_requests_total
      threshold: '100'
      query: sum(rate(http_requests_total[1m]))
```

## Common Scalers

KEDA supports 50+ scalers including:

- **AWS**: SQS, CloudWatch, DynamoDB, Kinesis
- **Azure**: Service Bus, Event Hubs, Storage Queue, Application Insights
- **GCP**: Pub/Sub, Cloud Storage, Cloud Monitoring
- **Databases**: PostgreSQL, MySQL, MongoDB, Redis
- **Message Queues**: Kafka, RabbitMQ, NATS
- **Metrics**: Prometheus, Datadog, New Relic
- **HTTP**: External endpoints, webhooks

## Notes

- KEDA operator is deployed in the `keda` namespace by default
- The module configures KEDA with recommended defaults for production use
- Resource limits match resource requests by default when using the `size` field
- Custom values are merged last, allowing full override of default configurations
- KEDA requires Kubernetes 1.23 or newer
- The module uses `wait=false` and `atomic=false` for faster deployment

## References

- [KEDA Official Documentation](https://keda.sh/docs/)
- [KEDA Scalers Documentation](https://keda.sh/docs/scalers/)
- [KEDA Helm Chart](https://github.com/kedacore/charts)
- [ScaledObject Specification](https://keda.sh/docs/concepts/scaling-deployments/)