# Cloud Account — Anycloud (AWS or GCP)

A multi-cloud reference cloud account. `spec.cloud_provider` (`AWS` or `GCP`)
picks the active cloud. It is the **only** per-environment cloud switch in an
anycloud blueprint. See [`modules/ANYCLOUD_PATTERN.md`](../../../ANYCLOUD_PATTERN.md).

- **Clouds:** aws, gcp
- **Resources created:** none (reads the cloud account secret, configures providers)
- **Output type:** `@facets/any_cloud_account`
- **Providers exposed:** `aws`, `google`, `google-beta` (always all three)

## Usage

```yaml
kind: cloud_account
flavor: anycloud
version: "1.0"
spec:
  cloud_provider: AWS      # override per environment: AWS | GCP
  # override-only, set for the selected cloud:
  # aws_cloud_account / aws_region   or   gcp_cloud_account / gcp_region
```

## Spec

| Field | Notes |
|-------|-------|
| `cloud_provider` | `AWS` or `GCP`. Required. |
| `aws_cloud_account`, `aws_region` | Shown when `cloud_provider = AWS`. Override-only. |
| `gcp_cloud_account`, `gcp_region` | Shown when `cloud_provider = GCP`. Override-only. |

## Outputs — `@facets/any_cloud_account`

| Attribute | Description |
|-----------|-------------|
| `cloud_provider` | `AWS` or `GCP`. Downstream modules branch on it. |
| `aws.role_arn`, `aws.external_id`, `aws.region` | Set on AWS; `null` on GCP |
| `gcp.project_id`, `gcp.credentials`, `gcp.region` | Set on GCP; `null` on AWS |
| `gcp.access_token` | `null` on GCP; a non-null stub on AWS so the google provider configures without ADC |

## Notes

- **The inactive cloud is null-keyed, never `{}`.** A `{}` loses its type
  across the module boundary and breaks the provider blocks.
- **Only the selected cloud's secret is fetched.** The two `data "external"`
  calls to the platform `secret-fetcher.py` are count-gated per cloud.
