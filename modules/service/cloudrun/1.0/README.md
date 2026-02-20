# Cloud Run Service Module

Deploys containerized applications to Google Cloud Run with auto-scaling, traffic management, and VPC connector support.

## Features

- **Auto-scaling**: Scale from 0 to N instances based on traffic
- **VPC Connector Support**: Connect to private VPC resources
- **Health Checks**: Configurable startup and liveness probes
- **Secret Manager Integration**: Mount secrets as environment variables
- **GCS Volume Mounts**: Mount GCS buckets using Cloud Storage FUSE
- **Deletion Protection**: Prevent accidental service deletion

## Usage

```yaml
kind: service
flavor: cloudrun
version: "1.0"
spec:
  container:
    image: gcr.io/my-project/my-app:latest
    port: "8080"
  scaling:
    min_instances: 0
    max_instances: 10
    concurrency: 80
  resources:
    cpu: 1000m
    memory: 512Mi
  auth:
    allow_unauthenticated: false
```

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| gcp_provider | @facets/gcp_cloud_account | Yes | GCP project and authentication |
| network | @facets/gcp-network-details | No | VPC network with vpc_connector_name |

## Outputs

This module outputs `@facets/service` type with:

### Attributes
- `service_name`: Cloud Run service name
- `namespace`: Service location/region
- `resource_name`: Blueprint resource name
- `resource_type`: "cloudrun"
- `selector_labels`: JSON-encoded labels
- `service_account_arn`: Service account email

### Interfaces
- `http`: HTTP endpoint interface with host, port, and connection details

## VPC Access

To enable VPC access for connecting to private resources:

1. Ensure your network module outputs `vpc_connector_name`
2. Enable VPC access in the spec:

```yaml
spec:
  vpc_access:
    enabled: true
    egress: private-ranges-only  # or all-traffic
```

## CPU Idle Behavior

The `cpu_idle` setting controls whether CPU is throttled when idle:
- If not explicitly set, defaults to `true` when `min_instances: 0` (scale-to-zero)
- If not explicitly set, defaults to `false` when `min_instances > 0`
- Can be explicitly set to override the default behavior
