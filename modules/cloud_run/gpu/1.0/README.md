# GPU Cloud Run Service Module

## Overview

This Facets module deploys a Google Cloud Run Gen 2 service with NVIDIA GPU acceleration. Purpose-built for AI/ML inference APIs, model serving, and GPU-accelerated HTTP workloads.

**Note:** This flavor deploys a persistent HTTP service. For batch workloads that run to completion, use the `gpu-job` or `gcp-job` flavor.

## Module Details

- **Intent:** `cloudrun`
- **Flavor:** `gpu`
- **Version:** `1.0`
- **Cloud:** GCP

## Features

- NVIDIA L4 (24GB VRAM, GA) or NVIDIA RTX Pro 6000 GPU acceleration
- Persistent HTTPS service endpoint with auto-scaling (including scale-to-zero)
- Startup and liveness health probes (HTTP or TCP)
- Secret Manager integration for environment variables
- GCS bucket volumes via Cloud Storage FUSE (ideal for ML model weights)
- VPC access with configurable egress routing
- Optional unauthenticated (public) access

## Dependencies (Inputs)

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `gcp_provider` | `@facets/gcp_cloud_account` | Yes | GCP project and authentication |
| `network` | `@facets/gcp-network-details` | No | VPC network for private connectivity |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `default` | `@facets/cloudrun` | Service name, location, URI, max instances |
| `attributes` | `@facets/cloudrun_attributes` | HTTP host, port, protocol for downstream consumers |

## Configuration Schema

### Container

```yaml
spec:
  container:
    image: ${blueprint.self.artifacts.cloudrun-gpu-service}
    port: "8080"
    command: []   # optional entrypoint override
    args: []
```

### GPU

```yaml
spec:
  gpu:
    enabled: true
    type: nvidia-l4              # nvidia-l4 (GA) or nvidia-rtx-pro-6000 (early access)
    zonal_redundancy: false      # reserve capacity across zones (additional cost)
```

### Resources

```yaml
spec:
  resources:
    cpu: "20"           # 20, 22, 24, 26, 30 vCPUs
    memory: 80Gi        # 80Gi, 96Gi, 104Gi, 128Gi
    cpu_throttling: false
    startup_cpu_boost: false
```

### Scaling

```yaml
spec:
  scaling:
    min_instances: 0    # 0 = scale to zero when idle
    max_instances: 1
    concurrency: 4      # keep low for GPU workloads
```

### Health Checks

```yaml
spec:
  health_checks:
    startup_probe:
      enabled: true
      type: tcp         # tcp or http
      port: "8080"
      period: 60
      timeout: 30
      failure_threshold: 10
    liveness_probe:
      enabled: false
```

### Secrets and Volumes

```yaml
spec:
  secrets:
    MY_API_KEY:
      secret_name: my-api-key
      version: latest
  gcs_volumes:
    models:
      bucket: my-ml-models-bucket
      mount_path: /models
      read_only: true
```

## Example Blueprint Resource

```yaml
kind: cloudrun
flavor: gpu
version: "1.0"
metadata:
  name: my-inference-api
disabled: false
spec:
  container:
    image: ${blueprint.self.artifacts.cloudrun-gpu-service}
    port: "8080"
  gpu:
    enabled: true
    type: nvidia-l4
    zonal_redundancy: false
  resources:
    cpu: "20"
    memory: 80Gi
    cpu_throttling: false
  scaling:
    min_instances: 0
    max_instances: 2
    concurrency: 4
  timeout: "600"
  health_checks:
    startup_probe:
      enabled: true
      type: tcp
      port: "8080"
      period: 60
      timeout: 30
      failure_threshold: 10
    liveness_probe:
      enabled: false
  gcs_volumes:
    models:
      bucket: my-ml-models
      mount_path: /models
      read_only: true
  auth:
    allow_unauthenticated: true
```

## Important Notes

- **GPU cold starts:** Set `startup_probe.period: 60` and `failure_threshold: 10` to allow up to 10 minutes for model initialization.
- **Request timeout:** Default is `600s`. Increase if model loading or inference can exceed 10 minutes.
- **Concurrency:** Keep low (e.g., 4) to avoid GPU resource contention across concurrent requests.
- **Scale to zero:** When `min_instances: 0`, the next request after idle will incur a GPU cold start. Set `min_instances: 1` for latency-sensitive services.
- **nvidia-rtx-pro-6000:** Requires GCP early access, minimum 20 vCPUs / 80GiB memory. Available in `us-central1`, `europe-west4`, `asia-south2`, `asia-southeast1`.
- **VPC network input:** Only required when `vpc_access.enabled: true`.
