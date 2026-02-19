# GPU Cloud Run Job Module

## Overview

This Facets module deploys a GPU-accelerated Google Cloud Run Job for long-running batch workloads. Jobs run to completion and exit — there is no HTTP server or persistent endpoint.

**Note:** This flavor is for batch workloads requiring GPU. For a persistent GPU HTTP service, use the `gpu` flavor. For batch workloads without GPU, use the `gcp-job` flavor.

## Module Details

- **Intent:** `cloudrun`
- **Flavor:** `gpu-job`
- **Version:** `1.0`
- **Cloud:** GCP

## Features

- NVIDIA RTX Pro 6000 GPU acceleration for batch workloads
- Tasks run up to 7 days (168 hours)
- Parallel task execution with configurable task count and parallelism
- Automatic retry on task failure
- Secret Manager integration for environment variables
- VPC access with configurable egress routing

## Dependencies (Inputs)

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `cloud_account` | `@facets/gcp_cloud_account` | Yes | GCP project and authentication |
| `network_details` | `@facets/gcp-network-details` | No | VPC network for private connectivity |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `attributes` | `@facets/cloudrun_attributes` | Job name, location, project ID, execution URL, GPU info, job config |

## Configuration Schema

### Container

```yaml
spec:
  container:
    image: ${blueprint.self.artifacts.video-processor}
    command: []   # optional entrypoint override
    args: []
```

### GPU

```yaml
spec:
  gpu:
    enabled: true
    type: nvidia-rtx-pro-6000    # only supported GPU type for jobs
```

### Resources

```yaml
spec:
  resources:
    cpu: "20"       # 20, 24, 32 vCPUs (minimum 20 required for RTX Pro 6000)
    memory: 80Gi    # 80Gi, 96Gi, 128Gi (minimum 80Gi required for RTX Pro 6000)
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
    - env_var: MY_API_KEY
      secret_name: my-api-key
      version: latest
```

### VPC Access

```yaml
spec:
  vpc_access:
    connector: my-vpc-connector
    egress: private-ranges-only    # private-ranges-only or all-traffic
```

## Example Blueprint Resource

```yaml
kind: cloudrun
flavor: gpu-job
version: "1.0"
metadata:
  name: my-video-processor
disabled: false
spec:
  container:
    image: ${blueprint.self.artifacts.video-processor}
  gpu:
    enabled: true
    type: nvidia-rtx-pro-6000
  resources:
    cpu: "20"
    memory: 80Gi
  job:
    task_count: 10
    parallelism: 2
    max_retries: 3
    task_timeout: 3600s
  secrets:
    - env_var: API_KEY
      secret_name: my-api-key
      version: latest
```

## Important Notes

- **nvidia-rtx-pro-6000 requirements:** Requires GCP early access approval, minimum 20 vCPUs and 80GiB memory. Available in `us-central1`, `europe-west4`, `asia-south2`, `asia-southeast1`.
- **Alpha launch stage:** GPU jobs run under Cloud Run's ALPHA launch stage. This is required by GCP for GPU job support.
- **Zonal redundancy disabled:** GPU zonal redundancy is always disabled for jobs — this is a GCP requirement.
- **No HTTP endpoint:** Jobs have no URL. They are triggered via the Cloud Run Admin API (`execution_url` in outputs).
- **Task vs parallelism:** `task_count` is the total number of tasks to complete; `parallelism` is how many run simultaneously. All tasks must succeed for the job to be considered complete.
- **VPC network input:** Only required when `vpc_access.connector` is specified.
