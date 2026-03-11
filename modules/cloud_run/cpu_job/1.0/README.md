# Cloud Run Job Module

## Overview

This Facets module deploys a standard Google Cloud Run Job for long-running batch workloads. Jobs run to completion and exit — there is no HTTP server or persistent endpoint.

**Note:** This flavor is for CPU-based batch workloads. For GPU-accelerated batch workloads, use the `gpu-job` flavor. For a persistent HTTP service, use the `gpu` flavor.

## Module Details

- **Intent:** `cloudrun`
- **Flavor:** `gcp-job`
- **Version:** `1.0`
- **Cloud:** GCP

## Features

- Tasks run up to 7 days (168 hours)
- Parallel task execution with configurable task count and parallelism
- Automatic retry on task failure
- Secret Manager integration for environment variables
- GCS bucket volumes via Cloud Storage FUSE
- VPC access with configurable egress routing
- Resource labels for cost allocation and organization

## Dependencies (Inputs)

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `gcp_provider` | `@facets/gcp_cloud_account` | Yes | GCP project and authentication |
| `network` | `@facets/gcp-network-details` | No | VPC network for private connectivity |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `default` | `@facets/cloudrun_job` | Job name, location, project ID, execution URI |
| `attributes` | `@facets/cloudrun_job_attributes` | Job attributes for downstream consumers |

## Configuration Schema

### Container

```yaml
spec:
  container:
    image: ${blueprint.self.artifacts.batch-processor}
    command: []   # optional entrypoint override
    args: []
```

### Resources

```yaml
spec:
  resources:
    cpu: "2"        # 1, 2, 4, 8 vCPUs
    memory: 4Gi     # 512Mi, 1Gi, 2Gi, 4Gi, 8Gi, 16Gi, 32Gi
```

### Job Configuration

```yaml
spec:
  job:
    task_count: 1        # 1–100, all tasks must succeed
    parallelism: 1       # 1–100, max tasks running in parallel
    max_retries: 3       # 0–10 retries per task before marking failed
    task_timeout: 3600s  # up to 168h (7 days)
```

### Secrets

```yaml
spec:
  secrets:
    MY_API_KEY:
      secret_name: my-api-key
      version: latest
    DB_PASSWORD:
      secret_name: db-password
      version: "2"
```

### GCS Bucket Volumes

```yaml
spec:
  gcs_volumes:
    input-data:
      bucket: my-input-bucket
      mount_path: /data/input
      read_only: true
    output-data:
      bucket: my-output-bucket
      mount_path: /data/output
      read_only: false
```

### VPC Access

```yaml
spec:
  vpc_access:
    enabled: true
    egress: private-ranges-only    # private-ranges-only or all-traffic
```

## Example Blueprint Resource

```yaml
kind: cloudrun
flavor: gcp-job
version: "1.0"
metadata:
  name: my-etl-job
disabled: false
spec:
  container:
    image: ${blueprint.self.artifacts.batch-processor}
  resources:
    cpu: "2"
    memory: 4Gi
  job:
    task_count: 1
    parallelism: 1
    max_retries: 3
    task_timeout: 3600s
  secrets:
    DB_PASSWORD:
      secret_name: db-password
      version: latest
  gcs_volumes:
    input-data:
      bucket: my-input-data
      mount_path: /data/input
      read_only: true
  vpc_access:
    enabled: true
    egress: private-ranges-only
  labels:
    team: data-engineering
    cost-center: platform
```

## Important Notes

- **No HTTP endpoint:** Jobs have no URL. They are triggered via the Cloud Run Admin API (`execution_url` in outputs).
- **Task vs parallelism:** `task_count` is the total number of tasks to complete; `parallelism` is how many run simultaneously. All tasks must succeed for the job to be considered complete.
- **GCS FUSE volumes:** Mounting large datasets from GCS avoids bundling data into the container image. Use `read_only: true` for input data to improve performance.
- **VPC network input:** Only required when `vpc_access.enabled: true`. When enabled, the network input must be wired to a GCP network module.
- **Secrets key format:** Secret keys must match `^[A-Z][A-Z0-9_]*$` (uppercase env var convention).
