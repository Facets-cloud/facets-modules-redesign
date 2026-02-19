# Cloud Tasks Queue Module

## Overview

This Facets module creates a GCP Cloud Tasks queue pre-wired to dispatch asynchronous jobs to a Cloud Run service. The queue handles URL routing and OIDC authentication at the queue level — clients only need to send the task payload body.

**Note:** Cloud Tasks is not available in all GCP regions (e.g., `asia-south2`/Delhi). Use the `region` spec field to override the queue region when needed (e.g., `asia-south1` for Mumbai).

## Module Details

- **Intent:** `cloud_tasks`
- **Flavor:** `queue`
- **Version:** `1.0`
- **Cloud:** GCP

## Features

- Automatically enables the Cloud Tasks API in the project
- Creates a dedicated invoker service account with `roles/run.invoker` on the target Cloud Run service
- Queue-level HTTP target: URL, OIDC auth, and `Content-Type` header are pre-configured
- Rate limiting based on Cloud Run's `max_instances`
- Configurable retry behavior (attempts, backoff, doublings)
- Override queue region independently of Cloud Run region

## Dependencies (Inputs)

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `cloud_account` | `@facets/gcp_cloud_account` | Yes | GCP project ID and region |
| `cloudrun` | `@facets/cloudrun` | Yes | Target Cloud Run service (provides URL, service name, location, max_instances) |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `default` | `@facets/cloud_tasks` | Queue name, path, API endpoint, invoker SA email, target URL |

### Output Attributes

| Attribute | Description |
|-----------|-------------|
| `queue_name` | Name of the created Cloud Tasks queue |
| `queue_path` | Full GCP resource path of the queue |
| `queue_region` | Region where the queue is deployed |
| `cloudrun_location` | Region of the target Cloud Run service |
| `project_id` | GCP project ID |
| `api_endpoint` | Cloud Tasks REST API endpoint for creating tasks |
| `target_url` | Cloud Run service URL (pre-configured in queue) |
| `target_path` | HTTP path tasks are dispatched to |
| `invoker_sa_email` | Service account used for OIDC authentication |
| `http_target_mode` | Always `queue_level` |

### Output Interfaces

| Interface | Description |
|-----------|-------------|
| `tasks_api` | HTTP POST endpoint with `Content-Type: application/json` |

## Configuration Schema

### Region Override

```yaml
spec:
  region: asia-south1   # Override when Cloud Tasks unavailable in Cloud Run's region
```

### Target Path

```yaml
spec:
  target_path: /process   # HTTP path on Cloud Run (default: /process)
```

### Retry Configuration

```yaml
spec:
  retry_config:
    max_attempts: 3       # 1-100, total attempts including first
    min_backoff: "10s"    # Minimum wait between retries
    max_backoff: "3600s"  # Maximum wait between retries
    max_doublings: 4      # 0-16, exponential backoff doublings
```

## Example Blueprint Resource

```yaml
kind: cloud_tasks
flavor: queue
version: "1.0"
disabled: false
spec:
  region: asia-south1
  target_path: /process
  retry_config:
    max_attempts: 3
    min_backoff: "10s"
    max_backoff: "3600s"
    max_doublings: 4
```

## Important Notes

- **Queue-level HTTP target:** URL, OIDC token, and `Content-Type` header are baked into the queue. Clients only need to `POST` the task body to `api_endpoint`.
- **Regional flexibility:** The queue can be in a different region than Cloud Run. Wire `region` to an available Cloud Tasks region when your Cloud Run service is in a region without Cloud Tasks support.
- **OIDC authentication:** The module creates and manages the invoker service account automatically. No manual IAM setup is required.
- **Rate limiting:** `max_concurrent_dispatches` is automatically set to the Cloud Run service's `max_instances` to prevent overload.
