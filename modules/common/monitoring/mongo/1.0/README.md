# MongoDB Monitoring Module

Creates Prometheus alert rules for monitoring MongoDB clusters running on KubeBlocks.

## Overview

This module generates `PrometheusRule` custom resources with alert rules specifically designed for MongoDB instances deployed via KubeBlocks. It uses the metrics exposed by the KubeBlocks MongoDB exporter.

## Features

- **7 Configurable Alert Rules**:
  - `mongodb_down` - Detects when MongoDB instance is unavailable
  - `mongodb_high_connections` - Monitors connection usage percentage
  - `mongodb_high_memory` - Tracks resident memory usage
  - `mongodb_replication_lag` - Monitors replication lag between PRIMARY and SECONDARY
  - `mongodb_replica_unhealthy` - Detects unhealthy replica set members
  - `mongodb_high_queued_operations` - Monitors global lock queue (readers + writers)
  - `mongodb_slow_queries` - Tracks elevated operation rates

- **Per-Alert Configuration**:
  - Enable/disable individual alerts
  - Adjustable severity levels (critical, warning, info)
  - Configurable thresholds
  - Customizable alert duration

- **KubeBlocks Integration**:
  - Uses KubeBlocks MongoDB exporter metrics (`mongodb_ss_*`, `mongodb_rs_*`)
  - Labels match KubeBlocks conventions (`app_kubernetes_io_instance`)
  - Compatible with KubeBlocks v1.0.1+

## Usage

```yaml
kind: monitoring
flavor: mongo
version: "1.0"
spec:
  prometheus_namespace: "monitoring"
  
  alerts:
    mongodb_down:
      enabled: true
      severity: "critical"
      for_duration: "1m"
    
    mongodb_high_connections:
      enabled: true
      severity: "warning"
      threshold: 80  # percentage
      for_duration: "5m"
    
    mongodb_high_memory:
      enabled: true
      severity: "warning"
      threshold_gb: 3
      for_duration: "5m"
    
    mongodb_replication_lag:
      enabled: true
      severity: "warning"
      threshold_seconds: 10
      for_duration: "2m"
    
    mongodb_replica_unhealthy:
      enabled: true
      severity: "critical"
      for_duration: "1m"
    
    mongodb_high_queued_operations:
      enabled: true
      severity: "warning"
      threshold: 100
      for_duration: "5m"
    
    mongodb_slow_queries:
      enabled: true
      severity: "info"
      threshold_ms: 100
      for_duration: "5m"
```

## Inputs

### Required Inputs

| Name | Type | Description |
|------|------|-------------|
| `kubernetes_cluster` | `@facets/kubernetes-details` | Kubernetes cluster for deploying alert rules |
| `mongo` | `@outputs/mongo` | MongoDB instance to monitor (must expose KubeBlocks metrics) |

### Spec Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `prometheus_namespace` | string | `"monitoring"` | Namespace where Prometheus is installed |
| `labels` | object | `{}` | Additional labels for PrometheusRule resources |
| `alerts.*` | object | See below | Individual alert configurations |

### Alert Configuration Parameters

Each alert supports these parameters:

- `enabled` (boolean) - Enable/disable the alert
- `severity` (string) - Alert severity: `critical`, `warning`, or `info`
- `for_duration` (string) - Duration before alert fires (e.g., `1m`, `5m`, `1h`)
- `threshold*` (number) - Alert-specific threshold value

## Outputs

| Name | Type | Description |
|------|------|-------------|
| `prometheus_rule_name` | string | Name of the created PrometheusRule resource |
| `namespace` | string | Namespace where PrometheusRule is deployed |
| `rule_group_name` | string | Name of the alert rule group |
| `enabled_alert_count` | number | Number of enabled alerts |
| `mongodb_service` | string | MongoDB service being monitored |

## KubeBlocks Metrics Reference

This module uses the following KubeBlocks MongoDB exporter metrics:

| Metric | Usage | Alert |
|--------|-------|-------|
| `up` | MongoDB availability | mongodb_down |
| `mongodb_ss_connections{conn_type="current\|available"}` | Connection usage | mongodb_high_connections |
| `mongodb_ss_mem{type="resident"}` | Memory usage | mongodb_high_memory |
| `mongodb_rs_members_optimeDate{member_state="PRIMARY\|SECONDARY"}` | Replication lag | mongodb_replication_lag |
| `mongodb_rs_members_health` | Replica health status | mongodb_replica_unhealthy |
| `mongodb_ss_globalLock_currentQueue_{readers\|writers}` | Queued operations | mongodb_high_queued_operations |
| `mongodb_ss_opcounters_total` | Operation rate | mongodb_slow_queries |

## Prerequisites

1. **Prometheus Operator** must be installed in the cluster
2. **KubeBlocks** v1.0.1 or higher with MongoDB addon enabled
3. **MongoDB exporter** must be enabled on the MongoDB cluster
4. **ServiceMonitor** should be configured to scrape MongoDB metrics

## Verification

After deploying this module, verify the PrometheusRule was created:

```bash
kubectl get prometheusrule -n monitoring
kubectl describe prometheusrule <rule-name> -n monitoring
```

Check if Prometheus is loading the rules:

```bash
# Port-forward to Prometheus
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090

# Open browser to http://localhost:9090/rules
# Or check via API
curl http://localhost:9090/api/v1/rules | jq '.data.groups[] | select(.name | contains("mongodb"))'
```

## Troubleshooting

### Alerts not firing

1. **Check if metrics are being scraped**:
   ```bash
   kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
   # Query: mongodb_ss_connections
   ```

2. **Verify ServiceMonitor exists**:
   ```bash
   kubectl get servicemonitor -A | grep mongo
   ```

3. **Check PrometheusRule status**:
   ```bash
   kubectl get prometheusrule -n monitoring -o yaml
   ```

### Metrics not available

1. **Ensure MongoDB exporter is enabled** in the MongoDB cluster spec:
   ```yaml
   monitoring:
     enabled: true
     exporter: mongodb
   ```

2. **Check if exporter pod is running**:
   ```bash
   kubectl get pods -n <namespace> | grep exporter
   kubectl logs -n <namespace> <exporter-pod>
   ```

## References

- [KubeBlocks MongoDB Alert Rules](https://github.com/apecloud/kubeblocks-addons/blob/main/examples/mongodb/alert-rules.yaml)
- [KubeBlocks MongoDB Addon](https://github.com/apecloud/kubeblocks-addons/tree/main/addons/mongodb)
- [Prometheus Operator API](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md#prometheusrule)

## License

Copyright © 2025 Facets.cloud
