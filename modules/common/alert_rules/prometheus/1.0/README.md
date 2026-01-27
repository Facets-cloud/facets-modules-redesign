# Alert Rules Module (Prometheus)

Generic alert rules module for defining custom Prometheus alerting rules.

## Overview

This module allows you to define custom alert rules for ANY service or application without being tied to specific technologies (MongoDB, Postgres, etc.). It deploys PrometheusRule CRDs to your Kubernetes cluster for evaluation by Prometheus Operator.

## Features

- **Generic & Technology-Agnostic**: Works with any metrics, not limited to specific services
- **Grouped Alert Rules**: Organize alerts into logical groups with independent evaluation intervals
- **User-Defined PromQL**: Full control over alert expressions and conditions
- **Flexible Labeling**: Add custom labels and annotations to alerts for routing and metadata
- **Multi-Flavor Architecture**: Designed for future extensibility (CloudWatch, Datadog, etc.)

## Usage

See facets.yaml for full spec schema and configuration options.

## Best Practices

### Metric Label Filtering

Follow the Facets standard pattern by filtering metrics using `facets_resource_type` and `facets_resource_name` labels in your PromQL expressions. This ensures alerts target specific resources precisely.

These labels are automatically added to metrics by monitoring modules (like `monitoring/mongo`) via ServiceMonitor metric relabeling.

## Examples

### API Health Monitoring
```yaml
kind: alert_rules
flavor: prometheus
spec:
  alert_groups:
    api_health:
      interval: "30s"
      rules:
        api_down:
          expression: 'up{facets_resource_type="service",facets_resource_name="api-service"} == 0'
          duration: "2m"
          severity: critical
          summary: "API service is down"
```

### Custom Business Metrics
```yaml
spec:
  alert_groups:
    business_metrics:
      rules:
        low_order_rate:
          expression: 'rate(orders_total{facets_resource_type="service",facets_resource_name="order-processor"}[10m]) < 5'
          duration: "10m"
          severity: warning
          summary: "Order rate below threshold"
          labels:
            team: revenue
```

## Requirements

- Kubernetes cluster with Prometheus Operator installed
- Prometheus instance deployed (via prometheus module)
