# MongoDB Monitoring Module

Complete monitoring stack for MongoDB instances with metrics collection, alerting, and real-time health monitoring.

## Overview

This module deploys a comprehensive monitoring solution for MongoDB clusters using Percona MongoDB Exporter v0.40. It includes intelligent alerting with PrometheusRule resources and seamless Prometheus integration via ServiceMonitor.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│         monitoring/mongo/1.0 Module                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. MongoDB Exporter (Helm Chart)                           │
│     └── Percona MongoDB Exporter v0.40.0                    │
│     └── Connects to MongoDB via URI                         │
│     └── Exposes metrics on port 9216                        │
│                                                             │
│  2. ServiceMonitor                                          │
│     └── Created by Helm chart                               │
│     └── Requires release label for Prometheus discovery     │
│     └── Scrapes every 30s (configurable)                    │
│                                                             │
│  3. PrometheusRule                                          │
│     └── 7 production-ready alert rules                      │
│     └── Uses validated metrics from exporter v0.40          │
│     └── Requires release label for Prometheus discovery     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## Environment as Dimension

This module is environment-aware and uses:
- `var.environment.unique_name` for unique resource naming across environments
- `var.environment.namespace` as fallback for MongoDB namespace detection
- Environment-specific labels applied to all resources

Each environment (dev, staging, prod) gets its own isolated exporter deployment and monitoring resources.

## Resources Created

- **Helm Release**: `prometheus-mongodb-exporter` chart (version 3.15.0)
- **Kubernetes Deployment**: Percona MongoDB Exporter (v0.40.0)
- **Kubernetes Service**: ClusterIP service exposing exporter metrics
- **ServiceMonitor**: Auto-created by Helm chart for Prometheus scraping
- **PrometheusRule**: Custom alert rules for MongoDB health and performance

## Features

### MongoDB Exporter (v0.40.0)

- **Comprehensive Metrics Collection** with `--collect-all` flag
- **Direct MongoDB Connection** using credentials from mongo input
- **Replica Set Aware** with `--mongodb.direct-connect=false`
- **Resource Optimized**: 100m CPU / 128Mi Memory requests

**Key Metrics Exposed:**
- Connection statistics (`mongodb_ss_connections`)
- Memory usage (`mongodb_ss_mem_resident`, `mongodb_ss_mem_virtual`)
- Replication lag and health (`mongodb_members_optimeDate`, `mongodb_members_health`)
- Global lock queue depth (`mongodb_ss_globalLock_currentQueue`)
- Slow query profiling (`mongodb_profile_slow_query_count`)
- Database operations and performance

### 7 Production-Ready Alert Rules

All alerts use validated metric names from Percona MongoDB Exporter v0.40.0:

| Alert | Default Threshold | Severity | For Duration | Description |
|-------|-------------------|----------|--------------|-------------|
| `mongodb_down` | N/A | Critical | 1m | Exporter cannot connect to MongoDB |
| `mongodb_high_connections` | 70% | Warning | 5m | Connection usage exceeds threshold |
| `mongodb_high_memory` | 3GB | Warning | 5m | Resident memory usage too high |
| `mongodb_replication_lag` | 10s | Warning | 2m | Replica lag exceeds threshold |
| `mongodb_replica_unhealthy` | N/A | Critical | 1m | Replica set member health = 0 |
| `mongodb_high_queued_operations` | 100 ops | Warning | 5m | Global lock queue backed up |
| `mongodb_slow_queries` | 10 queries/sec | Warning | 5m | Slow query rate exceeds threshold |

### Alert Details

#### mongodb_down
**Expression:** `mongodb_up{job="..."} == 0`
**Triggers when:** MongoDB is unreachable or connection fails
**Action Required:** Check MongoDB pods, network connectivity, credentials

#### mongodb_high_connections
**Expression:** `(current / available) * 100 > threshold`
**Triggers when:** Connection pool usage exceeds 70% (default)
**Action Required:** Scale MongoDB, optimize connection pooling, check for connection leaks

#### mongodb_high_memory
**Expression:** `mongodb_ss_mem_resident > 3GB`
**Triggers when:** Resident memory usage exceeds threshold
**Action Required:** Review working set size, add indexes, increase memory limits

#### mongodb_replication_lag
**Expression:** `(PRIMARY_optime - SECONDARY_optime) / 1000 > 10s`
**Triggers when:** Replication lag exceeds 10 seconds (default)
**Action Required:** Check network between replicas, review write load, verify replica health

#### mongodb_replica_unhealthy
**Expression:** `mongodb_members_health == 0`
**Triggers when:** Any replica set member reports unhealthy status
**Action Required:** Check replica logs with `rs.status()`, verify pod health

#### mongodb_high_queued_operations
**Expression:** `(readers + writers) > 100`
**Triggers when:** Global lock queue depth exceeds 100 operations
**Action Required:** Database overloaded - optimize queries, add indexes, scale resources

#### mongodb_slow_queries
**Expression:** `rate(mongodb_profile_slow_query_count[5m]) > 10`
**Triggers when:** Slow query rate exceeds 10 queries/sec
**Requires:** MongoDB profiling enabled with `db.setProfilingLevel(1, {slowms: 100})`
**Action Required:** Review slow queries in `db.system.profile`, add indexes, optimize queries

## Usage

```yaml
kind: monitoring
flavor: mongo
version: "1.0"
spec:
  # Feature toggles
  enable_metrics: true      # Deploy exporter and ServiceMonitor
  enable_alerts: true       # Deploy PrometheusRule

  # Metrics configuration
  metrics_interval: "30s"   # Prometheus scrape interval

  # Alert customization
  alerts:
    mongodb_down:
      enabled: true
      severity: "critical"
      for_duration: "1m"

    mongodb_high_connections:
      enabled: true
      severity: "warning"
      threshold: 70           # Percentage
      for_duration: "5m"

    mongodb_high_memory:
      enabled: true
      severity: "warning"
      threshold_gb: 3         # Gigabytes
      for_duration: "5m"

    mongodb_replication_lag:
      enabled: true
      severity: "warning"
      threshold_seconds: 10   # Seconds
      for_duration: "2m"

    mongodb_replica_unhealthy:
      enabled: true
      severity: "critical"
      for_duration: "1m"

    mongodb_high_queued_operations:
      enabled: true
      severity: "warning"
      threshold: 100          # Operations
      for_duration: "5m"

    mongodb_slow_queries:
      enabled: true
      severity: "warning"
      threshold: 10           # Queries per second
      for_duration: "5m"

  # Custom labels (optional)
  labels:
    team: "platform"
    component: "database"
```

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `kubernetes_cluster` | `@facets/kubernetes-details` | Yes | Kubernetes cluster for deployment |
| `mongo` | `@facets/mongo` | Yes | MongoDB instance to monitor (provides connection details) |
| `prometheus` | `@facets/prometheus` | Yes | Prometheus instance (provides namespace and release label) |

### Prometheus Input Requirements

The `prometheus` input must provide:
- `attributes.namespace` - Namespace where Prometheus is running
- `attributes.prometheus_release` - Release label for resource discovery

**Important:** Both ServiceMonitor and PrometheusRule require the `release` label matching Prometheus's `ruleSelector.matchLabels.release` and `serviceMonitorSelector.matchLabels.release`.

## Configuration Parameters

### Feature Flags

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enable_metrics` | boolean | `true` | Deploy exporter and ServiceMonitor |
| `enable_alerts` | boolean | `true` | Deploy PrometheusRule with alerts |

### Metrics Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `metrics_interval` | string | `"30s"` | Prometheus scrape interval |

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

Key metrics from Percona MongoDB Exporter v0.40.0:

| Metric | Labels | Type | Description |
|--------|--------|------|-------------|
| `mongodb_up` | `job` | Gauge | MongoDB availability (1=up, 0=down) |
| `mongodb_ss_connections` | `job`, `conn_type` | Gauge | Connection counts (current, available, active) |
| `mongodb_ss_mem_resident` | `job` | Gauge | Resident memory usage in bytes |
| `mongodb_ss_mem_virtual` | `job` | Gauge | Virtual memory usage in bytes |
| `mongodb_members_optimeDate` | `job`, `member_state`, `member_idx` | Gauge | Replication optime in milliseconds |
| `mongodb_members_health` | `job`, `member_state`, `member_idx` | Gauge | Replica member health (1=healthy, 0=unhealthy) |
| `mongodb_ss_globalLock_currentQueue` | `job`, `count_type` | Gauge | Global lock queue depth (readers, writers) |
| `mongodb_profile_slow_query_count` | `job`, `database` | Counter | Cumulative count of slow queries |

### Important Notes on Metrics

1. **Job Label Format**: All metrics include `job="<instance-name>-exporter-prometheus-mongodb-exporter"`
2. **Label Changes in v0.40**:
   - `type` → `conn_type` for connections
   - `type` → `count_type` for queued operations
   - `state` → `member_state` for replication metrics
3. **Memory Metrics**: Use suffix-based naming (`_resident`, `_virtual`) instead of type labels
4. **Time Units**: Replication lag is in milliseconds (converted to seconds in alerts)

## Prerequisites

1. **Kubernetes cluster** with sufficient resources
2. **Prometheus Operator** installed in the cluster
3. **Prometheus instance** with proper selectors:
   - `ruleSelector.matchLabels.release: <prometheus-release>`
   - `serviceMonitorSelector.matchLabels.release: <prometheus-release>`
4. **MongoDB instance** with accessible connection credentials
5. **Network connectivity** between exporter and MongoDB

## Verification

### Check Exporter Deployment

```bash
# Check if exporter pod is running
kubectl get pods -n <mongodb-namespace> | grep exporter

# View exporter logs
kubectl logs -n <mongodb-namespace> deployment/<instance-name>-exporter-prometheus-mongodb-exporter

# Check if exporter can connect to MongoDB (should see "MongoDB up")
kubectl logs -n <mongodb-namespace> deployment/<instance-name>-exporter-prometheus-mongodb-exporter | grep "up"
```

### Verify ServiceMonitor

```bash
# Check ServiceMonitor exists
kubectl get servicemonitor -n <mongodb-namespace>

# Verify it has the correct release label
kubectl get servicemonitor <instance-name>-exporter-prometheus-mongodb-exporter -n <mongodb-namespace> -o jsonpath='{.metadata.labels.release}'

# Should output: prometheus-<release-name>
```

### Check Prometheus Targets

```bash
# Port-forward to Prometheus
kubectl port-forward -n <prometheus-namespace> svc/prometheus-<release>-prometheus 9090:9090

# Open browser to http://localhost:9090/targets
# Search for: monitoring-mongo-exporter-prometheus-mongodb-exporter
# Status should be: UP
```

### Verify Metrics

```bash
# Query a basic metric
curl 'http://localhost:9090/api/v1/query' --data-urlencode 'query=mongodb_up{job="<instance-name>-exporter-prometheus-mongodb-exporter"}'

# Should return: "value": "1" (MongoDB is up)

# Check all available metrics
curl 'http://localhost:9090/api/v1/label/__name__/values' | jq '.data[] | select(contains("mongodb"))'
```

### Verify PrometheusRule

```bash
# Check PrometheusRule exists
kubectl get prometheusrule -n <prometheus-namespace>

# Verify it has the correct release label
kubectl get prometheusrule <instance-name>-alerts -n <prometheus-namespace> -o jsonpath='{.metadata.labels.release}'

# View all alert rules
kubectl get prometheusrule <instance-name>-alerts -n <prometheus-namespace> -o yaml

# Check alerts in Prometheus UI
# Go to http://localhost:9090/alerts
# Search for: Mongodb
```

### Test Alerts

```bash
# View current alert status
curl 'http://localhost:9090/api/v1/alerts' | jq '.data.alerts[] | select(.labels.alert_type | contains("mongodb"))'

# Manually trigger an alert (for testing)
# Example: Lower connection threshold temporarily to test high_connections alert
kubectl edit prometheusrule <instance-name>-alerts -n <prometheus-namespace>
# Change threshold from 70 to 1, wait 5 minutes, then revert
```

## Troubleshooting

### Exporter Pod Not Running

```bash
# Check pod status
kubectl get pods -n <mongodb-namespace> | grep exporter

# Describe pod for events
kubectl describe pod -n <mongodb-namespace> <exporter-pod-name>

# Check pod logs
kubectl logs -n <mongodb-namespace> <exporter-pod-name>

# Common issues:
# - MongoDB connection failed: Verify credentials in mongo input
# - Image pull errors: Check network connectivity, container registry access
# - CrashLoopBackOff: Check MongoDB URI format, network policies
# - OOMKilled: Increase memory limits in Helm values
```

### No Metrics in Prometheus

```bash
# 1. Verify ServiceMonitor exists
kubectl get servicemonitor -n <mongodb-namespace>

# 2. Check if ServiceMonitor has correct release label
kubectl get servicemonitor <name> -n <mongodb-namespace> -o jsonpath='{.metadata.labels.release}'

# 3. Verify Prometheus serviceMonitorSelector
kubectl get prometheus -n <prometheus-namespace> -o yaml | grep -A 5 serviceMonitorSelector

# 4. Check Prometheus logs for discovery errors
kubectl logs -n <prometheus-namespace> prometheus-<release>-prometheus-0

# 5. Port-forward and check targets
kubectl port-forward -n <prometheus-namespace> svc/prometheus-<release>-prometheus 9090:9090
# Go to http://localhost:9090/targets

# If target not found:
# - ServiceMonitor is missing the required 'release' label
# - Namespace is excluded by Prometheus namespaceSelector
# - Service selector doesn't match exporter service labels
```

### Alerts Not Firing

```bash
# 1. Check if PrometheusRule exists
kubectl get prometheusrule -n <prometheus-namespace>

# 2. Verify PrometheusRule has correct release label
kubectl get prometheusrule <instance-name>-alerts -n <prometheus-namespace> -o jsonpath='{.metadata.labels.release}'

# 3. Check Prometheus ruleSelector
kubectl get prometheus -n <prometheus-namespace> -o yaml | grep -A 5 ruleSelector

# 4. Verify Prometheus loaded the rules
# Go to http://localhost:9090/rules
# Search for: mongodb

# 5. Test alert expression manually
# Go to http://localhost:9090/graph
# Run the alert's PromQL query

# Common issues:
# - PrometheusRule missing 'release' label
# - Alert expression uses wrong job label
# - 'for' duration not met (alert pending)
# - Threshold not exceeded
```

### Wrong Job Label in Alerts

**Symptom:** Alerts never fire, queries return no results

**Cause:** Alert expressions use incorrect job label

**Fix:** The job label must match the ServiceMonitor/Service name created by Helm:
```
job="<instance-name>-exporter-prometheus-mongodb-exporter"
```

**Verify:**
```bash
# Check actual job label in metrics
curl 'http://localhost:9090/api/v1/query' --data-urlencode 'query=mongodb_up' | jq '.data.result[].metric.job'

# Update locals.tf if needed:
exporter_job_name = "${var.instance_name}-exporter-prometheus-mongodb-exporter"
```

### Slow Query Alert Always Zero

**Symptom:** `mongodb_slow_queries` alert never fires, metric shows 0

**Cause:** MongoDB profiling is not enabled

**Fix:**
```javascript
// Connect to MongoDB
mongo

// Enable profiling for slow queries (>100ms)
db.setProfilingLevel(1, { slowms: 100 })

// Verify profiling is enabled
db.getProfilingStatus()

// View slow queries
db.system.profile.find().sort({ts: -1}).limit(10)
```

### Replication Lag Alert False Positives

**Symptom:** Alert fires even when replication is healthy

**Cause:** Metric is in milliseconds, alert expects seconds

**Fix:** Ensure alert expression divides by 1000:
```promql
(max(mongodb_members_optimeDate{member_state="PRIMARY"}) - mongodb_members_optimeDate{member_state="SECONDARY"}) / 1000 > 10
```

## Security Considerations

- MongoDB connection URI is passed via Helm values (not stored in ConfigMap)
- Exporter runs with minimal permissions (no cluster-wide access)
- Metrics are scraped over HTTP within the cluster (not exposed externally)
- All resources are tagged with environment labels for isolation
- PrometheusRule and ServiceMonitor deployed in separate namespaces for security
- Sensitive metrics can be filtered using Prometheus relabeling rules

## Performance Impact

- **CPU Usage**: ~100m (0.1 core) per exporter instance
- **Memory Usage**: ~128Mi per exporter instance
- **Network**: Minimal - scrapes every 30s, ~10KB per scrape
- **MongoDB Impact**: Negligible - read-only operations, uses `serverStatus()`
- **Cardinality**: ~5,700 metrics per MongoDB cluster

## References

- [Percona MongoDB Exporter v0.40](https://github.com/percona/mongodb_exporter)
- [Prometheus MongoDB Exporter Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/prometheus-mongodb-exporter)
- [Prometheus Operator API](https://github.com/prometheus-operator/prometheus-operator/blob/main/Documentation/api.md)
- [MongoDB Monitoring Best Practices](https://docs.mongodb.com/manual/administration/monitoring/)
- [MongoDB Profiler Documentation](https://docs.mongodb.com/manual/tutorial/manage-the-database-profiler/)

## Version History

### 1.0.0
- Initial release with Percona MongoDB Exporter v0.40.0
- Helm chart deployment (prometheus-mongodb-exporter 3.15.0)
- 7 production-ready alert rules with validated metrics
- Support for MongoDB 4.4, 5.0, 6.0, 7.0, 8.0
- Environment-aware resource naming
- Automatic Prometheus discovery via ServiceMonitor
- Configurable thresholds and alert durations

## License

Copyright © 2025 Facets.cloud
