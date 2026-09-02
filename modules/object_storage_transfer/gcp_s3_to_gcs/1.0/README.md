# Object Storage Transfer — S3 to GCS

Transfers objects from an **AWS S3** bucket to a **Google Cloud Storage** bucket
using Google **Storage Transfer Service (STS)**. It wires up both sides of the
cross-cloud trust: an AWS IAM role and read-only S3 policy that Google's transfer
service agent can assume, GCS bucket IAM for the service agent to write, and the
STS transfer job itself. The job can run **once** or on a **recurring** schedule.

- **Clouds:** aws (source) + gcp (destination)
- **Inputs:** `@facets/aws_cloud_account`, `@facets/gcp_cloud_account`
- **Output type:** `@facets/object_storage_transfer`
- **Resources created:** AWS IAM role + policy + attachment, GCS bucket IAM
  members, the Storage Transfer job, and the enabled `storagetransfer` API

---

## Architecture

```
   SOURCE (AWS)                         GOOGLE Storage Transfer Service              TARGET (GCP)
   ┌──────────────────────┐            ┌────────────────────────────────────┐      ┌──────────────────┐
   │ S3 bucket + prefix    │  assumes   │ transfer job (one_time / recurring) │      │ GCS bucket +     │
   │ spec.source.*         │  IAM role  │  · reads S3 via aws_s3_data_source   │ write│ prefix           │
   │                       │ ◄───────── │  · writes GCS via gcs_data_sink      │ ────►│ spec.target.*    │
   │ IAM role + read-only  │  (web      │  · object filters + overwrite rules  │      │                  │
   │ S3 policy (created)   │  identity) │  · schedule + repeat_interval        │      │ service agent    │
   └──────────────────────┘            └──────────────────────────────────────┘      │ granted IAM      │
            ▲                                          ▲                              └──────────────────┘
            │ aws provider                             │ google provider
   @facets/aws_cloud_account                  @facets/gcp_cloud_account
```

The Google transfer service agent (a per-project Google-managed service account)
assumes the created AWS IAM role via `sts:AssumeRoleWithWebIdentity`, reads the
source bucket, and writes into the target bucket where it has been granted
`storage.objectAdmin` and `storage.legacyBucketReader`.

---

## Usage

```yaml
kind: object_storage_transfer
flavor: gcp_s3_to_gcs
version: "1.0"
disabled: false
spec:
  source:
    bucket: my-source-bucket
    prefix: exports/
    include_versions: false
  target:
    project_id: my-project
    bucket: my-target-bucket
    prefix: imports/
  schedule:
    status: ENABLED
    mode: one_time
    start_date: "2026-08-27"
    start_hour: 0
    start_minute: 0
    repeat_interval: 86400s
  options:
    overwrite_existing: true
    delete_extra_in_target: false
    include_prefixes: []
    exclude_prefixes: []
    min_age_seconds: 0
    api_propagation_wait_seconds: 90
  naming:
    transfer_job_description: ""
    aws_role_name: ""
    aws_policy_name: ""
```

---

## Inputs

| Input | Type | Providers | Purpose |
|-------|------|-----------|---------|
| `aws_provider` | `@facets/aws_cloud_account` | aws | AWS account containing the source S3 bucket; where the IAM role/policy are created. |
| `gcp_provider` | `@facets/gcp_cloud_account` | google | GCP project containing the destination bucket and the Storage Transfer job. |

---

## Spec

### `source`

| Field | Required | Notes |
|-------|----------|-------|
| `bucket` | Yes | Existing S3 bucket name to read from. |
| `prefix` | No | Prefix inside the source bucket. Default `""` (whole bucket). |
| `include_versions` | No | Allow reads from versioned objects; adds `s3:ListBucketVersions` / `s3:GetObjectVersion` to the policy. Default `false`. |
| `kms_key_arns` | No | AWS KMS key ARNs needed to decrypt SSE-KMS objects; adds `kms:Decrypt`/`kms:DescribeKey`. Default `[]`. |

### `target`

| Field | Required | Notes |
|-------|----------|-------|
| `project_id` | Yes | GCP project where the transfer job runs. |
| `bucket` | Yes | Existing GCS bucket name to write into. |
| `prefix` | No | Destination prefix inside the GCS bucket. Default `""`. |

### `schedule`

| Field | Default | Notes |
|-------|---------|-------|
| `status` | `ENABLED` | `ENABLED` or `DISABLED` — whether the job is active. |
| `mode` | `one_time` | `one_time` runs once; `recurring` keeps syncing. |
| `start_date` | `2026-08-27` | Start date, `YYYY-MM-DD`. |
| `end_date` | `""` | Optional end date for recurring jobs. Blank means no explicit end. |
| `start_hour` | `0` | Hour of day, UTC (0–23). |
| `start_minute` | `0` | Minute of hour (0–59). |
| `repeat_interval` | `86400s` | Terraform duration (e.g. `3600s`). Used only when `mode` is `recurring`. |

### `options`

| Field | Default | Notes |
|-------|---------|-------|
| `overwrite_existing` | `true` | Replace target objects when the source differs. |
| `delete_extra_in_target` | `false` | Mirror-delete objects that exist only in the target prefix. |
| `include_prefixes` | `[]` | Object prefixes to include, relative to the source bucket. |
| `exclude_prefixes` | `[]` | Object prefixes to exclude, relative to the source bucket. |
| `min_age_seconds` | `0` | Skip objects modified more recently than this many seconds (0–604800). |
| `api_propagation_wait_seconds` | `90` | Seconds to wait after enabling the Storage Transfer API before reading the service agent (0–600). |

### `naming`

| Field | Default | Notes |
|-------|---------|-------|
| `transfer_job_description` | `""` | Job description. Blank derives from the resource name. |
| `aws_role_name` | `""` | IAM role name override (override-only). Blank derives from the resource name. |
| `aws_policy_name` | `""` | IAM policy name override (override-only). Blank derives from the resource name. |

---

## Outputs — `@facets/object_storage_transfer`

### Attributes

| Attribute | Description |
|-----------|-------------|
| `transfer_job_name` | The Storage Transfer job resource name. |
| `transfer_job_description` | The job description. |
| `status` | Job status (`ENABLED` / `DISABLED`). |
| `aws_role_arn` | ARN of the created AWS IAM role. |
| `aws_role_name` | Name of the created AWS IAM role. |
| `aws_policy_arn` | ARN of the created read-only S3 policy. |
| `source_bucket` / `source_prefix` | Source S3 bucket and prefix. |
| `target_project_id` / `target_bucket` / `target_prefix` | Target project, bucket, and prefix. |
| `mode` | Schedule mode (`one_time` / `recurring`). |
| `repeat_interval` | Repeat interval, or null for one-time jobs. |

### Interfaces

| Interface | Fields |
|-----------|--------|
| `transfer` | `job_name`, `source_bucket`, `source_prefix`, `target_bucket`, `target_prefix`, `target_project_id` |

---

## Notes

- **Source data is read-only.** The generated S3 policy grants only list and get
  actions; `delete_objects_from_source_after_transfer` is always false, so the
  transfer never deletes from S3.
- **Schedule behavior.** `one_time` sets an end date equal to the start date and
  drops `repeat_interval`. `recurring` uses `repeat_interval` and honors an
  optional `end_date`.
- **`delete_extra_in_target` is destructive on the target.** When true, objects
  present only under the target prefix are deleted to mirror the source. Leave it
  false unless you intend an exact mirror.
- **API propagation wait.** After enabling `storagetransfer.googleapis.com`, the
  module waits `api_propagation_wait_seconds` before reading the transfer service
  agent, avoiding a race where the agent is not yet provisioned. Increase it if
  the agent lookup fails on first apply.
- **KMS-encrypted sources.** If source objects use SSE-KMS, set
  `source.kms_key_arns` so the role can decrypt them; otherwise reads fail.
- **Existing buckets required.** Both the source S3 bucket and target GCS bucket
  must already exist — this module wires transfer and IAM, it does not create the
  buckets.
