# Log Collector (Loki) Module

Grafana Loki distributed logging stack with Promtail log collector, optional Minio storage backend, and Loki Canary monitoring. Supports external storage (AWS S3, GCS, Azure Blob) and Prometheus integration for alerting.

## Features

- **Loki Distributed Architecture**: Scalable, multi-component Loki deployment (distributor, ingester, querier, compactor, gateway)
- **Promtail Log Shipper**: Automatic log collection from all Kubernetes pods
- **Minio S3-Compatible Storage**: Internal object storage for log retention (can be disabled for external storage)
- **Grafana Integration**: Automatic datasource configuration for Grafana
- **Prometheus Integration**: Optional integration for alerting and metrics
- **Loki Canary**: Synthetic log generation for monitoring stack health
- **Kubelet Log Scraping**: Optional systemd journal log collection from Kubernetes nodes
- **AWS Route53**: Optional DNS record creation for external Loki access
- **Autoscaling**: HPA-enabled components for production workloads

## Architecture

### Components

1. **Loki Distributed**:
   - **Distributor**: Accepts log streams and distributes them to ingesters
   - **Ingester**: Writes log data to storage and serves recent queries
   - **Querier**: Queries log data from ingesters and long-term storage
   - **Query Frontend**: Provides query queueing and result caching
   - **Compactor**: Compacts and deduplicates log indices
   - **Ruler**: Evaluates recording and alerting rules (when configured)
   - **Gateway**: NGINX reverse proxy for all components

2. **Promtail**: DaemonSet that ships logs from all pods to Loki

3. **Minio**: Distributed object storage for logs (disabled if using external storage)

4. **Loki Canary** (optional): Generates synthetic logs to test the stack

## Usage

### Basic Configuration

```yaml
kind: log_collector
flavor: loki
version: '1.0'
spec:
  retention_days: 7
  storage_size: "10Gi"
  ingester_pvc_size: "10Gi"
  querier_pvc_size: "10Gi"
```

### With Kubelet Log Scraping

```yaml
spec:
  enable_kubelet_log_scraping: true
  kubelet_scrape_extra_matches:
    - "cron.service"
    - "containerd.service"
  retention_days: 14
  storage_size: "50Gi"
```

### With AWS Route53

```yaml
spec:
  enable_route53_record: true
  route53_domain_prefix: "loki"
  route53_zone_id: "Z1234567890ABC"
  route53_base_domain: "example.com"
  # Creates: loki.example.com
```

### With External S3 Storage

```yaml
spec:
  loki_helm_values:
    loki:
      structuredConfig:
        storage_config:
          aws:
            s3: "s3://us-east-1/my-loki-bucket"
            access_key_id: "AKIA..."
            secret_access_key: "..."
  # Minio will be automatically disabled
```

### With Loki Canary Monitoring

```yaml
spec:
  enable_loki_canary: true
  loki_query_timeout: 120
```

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `kubernetes_details` | `@facets/kubernetes-details` | Yes | Kubernetes cluster for deployment |
| `prometheus` | `@facets/prometheus` | No | Prometheus instance for alerting integration |
| `aws_cloud_account` | `@facets/aws_cloud_account` | No | AWS account for Route53 (required if `enable_route53_record` is true) |

## Outputs

| Attribute | Type | Description |
|-----------|------|-------------|
| `loki_endpoint` | string | Loki gateway service endpoint (internal cluster URL) |
| `loki_namespace` | string | Kubernetes namespace where Loki is deployed |
| `gateway_fqdn` | string | Route53 FQDN for Loki gateway (null if Route53 disabled) |
| `minio_endpoint` | string | Minio service endpoint (null if using external storage) |
| `datasource_name` | string | Grafana datasource name ("Facets Loki") |

## Configuration Reference

### Spec Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `retention_days` | integer | 7 | Number of days to retain logs in Minio (1-365) |
| `storage_size` | string | "5Gi" | PVC size for Minio storage per replica |
| `ingester_pvc_size` | string | "5Gi" | PVC size for Loki ingester per replica |
| `querier_pvc_size` | string | "5Gi" | PVC size for Loki querier per replica |
| `loki_query_timeout` | integer | 60 | Maximum query execution time in seconds (10-600) |
| `enable_loki_canary` | boolean | false | Deploy Loki Canary for synthetic log testing |
| `enable_kubelet_log_scraping` | boolean | false | Scrape systemd journal logs from nodes |
| `kubelet_scrape_extra_matches` | array | [] | Additional systemd units to scrape |
| `use_docker_parser` | boolean | false | Use Docker log parser instead of CRI |
| `enable_default_pack` | boolean | true | Pack logs by pod/container/job labels |
| `enable_route53_record` | boolean | false | Create Route53 DNS record (AWS only) |
| `route53_domain_prefix` | string | - | Domain prefix for Route53 record |
| `route53_zone_id` | string | - | Route53 hosted zone ID |
| `route53_base_domain` | string | - | Base domain for Route53 record |
| `derived_fields` | object | {} | Grafana derived fields for trace integration |
| `loki_helm_values` | object | {} | Additional Helm values for Loki chart |
| `promtail_helm_values` | object | {} | Additional Helm values for Promtail chart |
| `minio_helm_values` | object | {} | Additional Helm values for Minio chart |

### Resource Requirements

**Loki Components** (default):
- Distributor: 300Mi-1Gi memory, 300m-1000m CPU (autoscaling 1-5 replicas)
- Ingester: 500Mi-4Gi memory, 300m-1000m CPU (autoscaling 3-5 replicas)
- Querier: 300Mi-4Gi memory, 300m-1000m CPU (autoscaling 1-10 replicas)
- Query Frontend: 300Mi-1Gi memory, 300m-1000m CPU (autoscaling 1-5 replicas)
- Compactor: 300Mi-1Gi memory, 300m-1000m CPU
- Gateway: 300Mi-1Gi memory, 300m-1000m CPU

**Promtail** (default):
- 100Mi-1Gi memory, 100m-1000m CPU per node

**Minio** (default):
- 100Mi-1Gi memory, 100m-1000m CPU per replica (4 replicas)

## Advanced Configuration

### External Storage Configuration

To use external S3, GCS, or Azure Blob storage, configure `loki_helm_values.loki.structuredConfig.storage_config`:

```yaml
spec:
  loki_helm_values:
    loki:
      structuredConfig:
        storage_config:
          aws:  # Or 'gcs' or 'azure'
            s3: "s3://us-east-1/my-bucket"
            access_key_id: "..."
            secret_access_key: "..."
```

When external storage is configured, Minio will be automatically disabled.

### Custom Helm Values

Override any Loki, Promtail, or Minio Helm chart values:

```yaml
spec:
  loki_helm_values:
    ingester:
      replicas: 5
      resources:
        limits:
          memory: "8Gi"
  promtail_helm_values:
    resources:
      limits:
        memory: "2Gi"
```

## Monitoring

- **ServiceMonitor**: All components expose Prometheus metrics via ServiceMonitor
- **Grafana Datasource**: Automatic datasource creation in Grafana namespace
- **Loki Canary** (optional): Synthetic log generation for end-to-end testing

## Storage

### Persistent Volumes

The module creates PVCs for:
1. **Loki Ingester**: Stores recent log chunks (per replica)
2. **Loki Querier**: Stores query cache (per replica)
3. **Minio**: Stores long-term logs (per replica, if not using external storage)

### Retention Policy

Logs in Minio are automatically expired after `retention_days` using MinIO lifecycle policies.

## Troubleshooting

### Pods Not Starting

Check PVC provisioning:
```bash
kubectl get pvc -n <loki_namespace>
```

### Logs Not Appearing

1. Check Promtail pods are running:
```bash
kubectl get pods -n <loki_namespace> -l app.kubernetes.io/name=promtail
```

2. Check Promtail logs:
```bash
kubectl logs -n <loki_namespace> -l app.kubernetes.io/name=promtail
```

3. Verify Loki gateway is accessible:
```bash
kubectl port-forward -n <loki_namespace> svc/<instance-name>-loki-distributed-gateway 3100:80
curl http://localhost:3100/ready
```

### Query Timeouts

Increase `loki_query_timeout` in spec or adjust Loki querier resources.

## Version History

- **1.0**: Initial release
  - Loki distributed architecture
  - Promtail log shipper
  - Minio internal storage
  - Optional external storage support
  - Optional Loki Canary
  - Optional Route53 integration
  - Grafana datasource auto-configuration
