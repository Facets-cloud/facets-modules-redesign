# GCP Service Account Module

## Overview

This Facets module creates and manages a GCP service account with fine-grained IAM role bindings across multiple GCP resource types. It supports project-level and resource-level bindings for storage buckets, BigQuery datasets, Pub/Sub topics, Secret Manager secrets, Cloud KMS keys, Artifact Registry repositories, Cloud Run services, Cloud Run jobs, and Cloud Tasks queues.

## Module Details

- **Intent:** `service_account`
- **Flavor:** `gcp`
- **Version:** `1.0`
- **Cloud:** GCP

## Features

- Creates a GCP service account with configurable display name and description
- Supports IAM bindings across 11 GCP resource types in a single module
- Optional service account key creation
- Automatic service account ID sanitization (lowercase, hyphens, max 30 chars)
- Location-aware bindings for regional resources (Cloud Run, Cloud Tasks)

## Dependencies (Inputs)

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `cloud_account` | `@facets/gcp_cloud_account` | Yes | GCP project ID, credentials, and region |

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `default` | `@facets/gcp_service_account` | Service account email, name, ID, unique ID, and optional private key |

### Output Attributes

| Attribute | Description |
|-----------|-------------|
| `service_account_id` | The account ID (short name) |
| `service_account_email` | Full email address of the service account |
| `service_account_name` | Full resource name |
| `unique_id` | GCP-assigned unique numeric ID |
| `project_id` | GCP project ID |
| `private_key` | Base64-encoded private key JSON (only if `create_key: true`) |

## Configuration Schema

### Basic Configuration

```yaml
spec:
  display_name: My Service Account
  description: Service account for application access
```

### IAM Bindings

Bindings are keyed by a unique name. Supported `resource_type` values:

| Resource Type | Required Fields | Optional Fields |
|---|---|---|
| `project` | `role` | — |
| `storage_bucket` | `role`, `resource_name` | — |
| `bigquery_dataset` | `role`, `resource_name` | — |
| `pubsub_topic` | `role`, `resource_name` | — |
| `pubsub_subscription` | `role`, `resource_name` | — |
| `secret_manager_secret` | `role`, `resource_name` | — |
| `kms_crypto_key` | `role`, `resource_name` | — |
| `kms_key_ring` | `role`, `resource_name` | — |
| `artifact_registry_repository` | `role`, `resource_name` | — |
| `cloud_run_service` | `role`, `resource_name` | `location` |
| `cloud_run_job` | `role`, `resource_name` | `location` |
| `cloud_tasks_queue` | `role`, `resource_name` | `location` |

```yaml
spec:
  display_name: App Service Account
  iam_bindings:
    gcs-reader:
      resource_type: storage_bucket
      resource_name: my-data-bucket
      role: roles/storage.objectViewer
    bq-editor:
      resource_type: bigquery_dataset
      resource_name: my_dataset
      role: roles/bigquery.dataEditor
    secret-accessor:
      resource_type: secret_manager_secret
      resource_name: my-api-key
      role: roles/secretmanager.secretAccessor
    cloudrun-invoker:
      resource_type: cloud_run_service
      resource_name: my-service
      role: roles/run.invoker
      location: us-central1   # override region if different from cloud_account region
```

### Service Account Key

```yaml
spec:
  display_name: CI/CD Service Account
  create_key: true   # creates a JSON key; output in private_key attribute
```

## Example Blueprint Resource

```yaml
kind: service_account
flavor: gcp
version: "1.0"
disabled: false
spec:
  display_name: Data Pipeline SA
  description: Service account for ETL pipeline access
  iam_bindings:
    gcs-input:
      resource_type: storage_bucket
      resource_name: raw-data-bucket
      role: roles/storage.objectViewer
    gcs-output:
      resource_type: storage_bucket
      resource_name: processed-data-bucket
      role: roles/storage.objectAdmin
    bq-writer:
      resource_type: bigquery_dataset
      resource_name: analytics
      role: roles/bigquery.dataEditor
    secret-reader:
      resource_type: secret_manager_secret
      resource_name: db-password
      role: roles/secretmanager.secretAccessor
```

## Important Notes

- **Service account ID:** Auto-generated from `instance_name` + `environment.unique_name`, truncated to 30 characters. Non-alphanumeric characters are replaced with hyphens.
- **Regional resources:** `cloud_run_service`, `cloud_run_job`, and `cloud_tasks_queue` require a `location`. If omitted, it defaults to the `cloud_account` region.
- **Service account keys:** Creating keys (`create_key: true`) is generally discouraged in favour of Workload Identity. Use only when no alternative is available. The `private_key` output is sensitive.
- **Project binding:** Use `resource_type: project` for project-wide roles (no `resource_name` needed).
