# MongoDB Monitoring Module

Complete monitoring stack for MongoDB instances with metrics collection, alerting, and visualization.

## Overview

This module deploys a comprehensive monitoring solution for MongoDB clusters. It includes a Percona MongoDB Exporter that connects directly to MongoDB and exposes detailed metrics, PrometheusRule resources for intelligent alerting, ServiceMonitor for Prometheus integration.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│         monitoring/mongo/1.0 Module                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. MongoDB Exporter Deployment                             │
│     └── Connects to MongoDB via connection string           │
│     └── Exposes metrics on port 9216                        │
│                                                             │
│  2. ServiceMonitor                                          │
│     └── Scrapes metrics from exporter service               │
│     └── Works with universal Prometheus discovery           │
│                                                             │
│  3. PrometheusRule                                          │
│     └── 7 configurable alert rules                          │
│     └── Uses real MongoDB metrics for alerting              │
│                                                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Environment as Dimension

This module is environment-aware and uses:
- `var.environment.unique_name` for unique resource naming across environments
- `var.environment.namespace` as fallback for MongoDB namespace detection
- `var.environment.cloud_tags` for applying environment-specific tags to all resources

Each environment (dev, staging, prod) gets its own isolated exporter deployment and monitoring resources.

## Resources Created

- **Kubernetes Secret**: Stores MongoDB connection URI securely
- **Kubernetes Deployment**: Runs Percona MongoDB Exporter (v0.40)
- **Kubernetes Service**: ClusterIP service exposing exporter metrics
- **ServiceMonitor**: Configures Prometheus to scrape exporter metrics
- **PrometheusRule**: Defines alert rules for MongoDB health and performance

## Features

### MongoDB Exporter
- Deploys Percona MongoDB Exporter 0.40
- Connects directly to MongoDB using credentials from mongo input
- Exposes comprehensive metrics including:
  - Connection statistics
  - Memory usage (resident/virtual)
  - Operations per second
  - Replication status and lag
  - Global lock queue depth
  - Replica set health

### 7 Configurable Alert Rules

Each alert can be enabled/disabled and configured with custom thresholds:

| Alert | Default Threshold | Severity | Description |
|-------|-------------------|----------|-------------|
| `mongodb_down` | N/A | Critical | MongoDB instance unavailable |
| `mongodb_high_connections` | 80% | Warning | Connection usage exceeds limit |
| `mongodb_high_memory` | 3GB | Warning | Resident memory usage too high |
| `mongodb_replication_lag` | 10s | Warning | Replica lag exceeds threshold |
| `mongodb_replica_unhealthy` | N/A | Critical | Replica set member unhealthy |
| `mongodb_high_queued_operations` | 100 ops | Warning | Global lock queue backed up |
| `mongodb_slow_queries` | 100 ms | Info | Elevated operation rate detected |


## Usage

```yaml
kind: monitoring
flavor: mongo
version: "1.0"
spec:
  # Feature toggles
  enable_metrics: true
  enable_alerts: true
  
  # Metrics configuration
  metrics_interval: "30s"
  
  
  # Alert customization
  alerts:
    mongodb_down:
      enabled: true
      severity: "critical"
      for_duration: "1m"
    
    mongodb_high_connections:
      enabled: true
      severity: "warning"
      threshold: 80
      for_duration: "5m"
    
    mongodb_high_memory:
      enabled: true
      severity: "warning"
      threshold_gb: 3
      for_duration: "5m"
```

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `kubernetes_cluster` | `@facets/kubernetes-details` | Yes | Kubernetes cluster for deployment |
| `mongo` | `@facets/mongo` | Yes | MongoDB instance to monitor (provides connection credentials) |
| `prometheus` | `@facets/prometheus` | Yes | Prometheus instance (provides namespace and Grafana integration) |

## Configuration Parameters

### Feature Flags

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enable_metrics` | boolean | `true` | Deploy exporter and ServiceMonitor |
| `enable_alerts` | boolean | `true` | Deploy PrometheusRule with alerts |

### Metrics Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `metrics_interval` | string | `"30s"` | How often Prometheus scrapes metrics |

### Alert Configuration

Each alert supports these parameters:
- `enabled` (boolean) - Enable/disable the alert
- `severity` (string) - Alert severity: `critical`, `warning`, or `info`
- `for_duration` (string) - Duration before alert fires (e.g., `1m`, `5m`)
- `threshold*` (number) - Alert-specific threshold value

## Outputs

| Name | Description |
|------|-------------|
| `exporter_enabled` | Whether metrics collection is enabled |
| `exporter_deployment` | Name of the MongoDB Exporter deployment |
| `exporter_service` | Name of the exporter service |
| `service_monitor_name` | Name of the ServiceMonitor resource |
| `prometheus_rule_name` | Name of the PrometheusRule resource |
| `alerts_enabled` | Whether alerts are enabled |
| `enabled_alert_count` | Number of enabled alerts |
| `mongodb_namespace` | Namespace where MongoDB is running |

## Metrics Reference

The Percona MongoDB Exporter exposes these key metrics:

| Metric | Description | Used By |
|--------|-------------|---------|
| `mongodb_up` | MongoDB availability (1=up, 0=down) | mongodb_down alert |
| `mongodb_ss_connections` | Current and available connections | mongodb_high_connections alert |
| `mongodb_ss_mem` | Memory usage (resident/virtual) | mongodb_high_memory alert |
| `mongodb_mongod_replset_optime_date` | Replication optime | mongodb_replication_lag alert |
| `mongodb_mongod_replset_member_health` | Replica member health | mongodb_replica_unhealthy alert |
| `mongodb_ss_globalLock_currentQueue` | Global lock queue depth | mongodb_high_queued_operations alert |
| `mongodb_ss_opcounters` | Operation counters | mongodb_slow_queries alert |

## Prerequisites

1. **Kubernetes cluster** with sufficient resources
2. **Prometheus Operator** installed in the cluster
3. **MongoDB instance** with accessible connection credentials
4. **Grafana** deployed (typically with Prometheus via kube-prometheus-stack)

## Verification

### Check Exporter Deployment

```bash
kubectl get deployment -n <namespace> | grep exporter
kubectl logs -n <namespace> deployment/<instance-name>-exporter
```

### Verify ServiceMonitor

```bash
kubectl get servicemonitor -n <namespace>
kubectl describe servicemonitor <instance-name>-exporter -n <namespace>
```

### Check Prometheus Targets

```bash
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Open browser to http://localhost:9090/targets
# Look for serviceMonitor/<namespace>/<instance-name>-exporter
```

### Verify PrometheusRule

```bash
kubectl get prometheusrule -n monitoring
kubectl describe prometheusrule <instance-name>-alerts -n monitoring
```


## Troubleshooting

### Exporter Pod Not Running

```bash
# Check pod status
kubectl get pods -n <namespace> | grep exporter

# Check pod logs
kubectl logs -n <namespace> <exporter-pod-name>

# Common issues:
# - MongoDB connection failed: Verify credentials in mongo input
# - Image pull errors: Check network connectivity
# - OOMKilled: Increase memory limits
```

### No Metrics in Prometheus

```bash
# Verify ServiceMonitor exists
kubectl get servicemonitor -n <namespace>

# Check if Prometheus discovered the target
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090
# Go to http://localhost:9090/targets

# If target not found:
# - Check Prometheus logs for discovery errors
# - Verify ServiceMonitor labels match Prometheus selectors
# - Ensure namespace is not excluded by Prometheus
```

### Alerts Not Firing

```bash
# Check if PrometheusRule was created
kubectl get prometheusrule -n monitoring

# Verify Prometheus loaded the rules
# Go to http://localhost:9090/rules
# Look for your alert rules

# Test alert expression manually
# Go to http://localhost:9090/graph
# Run the alert's PromQL query
```


## Security Considerations

- MongoDB connection credentials are stored in Kubernetes Secrets
- Exporter runs with minimal permissions (no cluster-wide access)
- Metrics are scraped over HTTP within the cluster (not exposed externally)
- All resources are tagged with environment labels for isolation
- Sensitive metrics (if any) can be filtered at Prometheus level

## References

- [Percona MongoDB Exporter](https://github.com/percona/mongodb_exporter)
- [Prometheus Operator API](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md)
- [MongoDB Monitoring Best Practices](https://docs.mongodb.com/manual/administration/monitoring/)

## License

Copyright © 2025 Facets.cloud
