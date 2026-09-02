# GCP Log Sink — Standard (Audit Evidence Export)

Creates a **folder-scoped aggregated Cloud Logging sink** that exports logs from
a folder and all its descendant projects into a **versioned, retention-locked GCS
bucket** in a separate project. Use it for audit/evidence retention where logs
must be captured centrally and held immutably for a fixed period. Optional CMEK
encrypts the bucket.

- **Cloud:** gcp
- **Resources created:** one GCS audit bucket, one folder sink, one bucket IAM
  grant for the sink writer
- **Output type:** `@facets/gcp_log_sink`

---

## Architecture

```
   INPUTS                                   RESOURCES (main.tf)                        OUTPUT
   ┌────────────────────────────┐           ┌───────────────────────────────────┐     ┌───────────────────┐
   │ cloud_account              │           │ google_storage_bucket "audit"     │     │ @facets/          │
   │  @facets/gcp_org_account   │──google─► │  versioning ON · uniform access   │     │  gcp_log_sink     │
   │                            │           │  retention_policy (days, locked)  │     │   bucket_name     │
   │ project                    │           │  encryption <= kms (optional)     │     │   bucket_url      │
   │  @facets/gcp_project        │──bucket──►└──────────────┬────────────────────┘     │   sink_name       │
   │  (holds the bucket)        │                          │ destination             │   writer_identity │
   │                            │           ┌──────────────▼────────────────────┐     │   retention_days  │
   │ folder                     │           │ google_logging_folder_sink "this" │────►│   retention_locked│
   │  @facets/gcp_folder         │──folder──►│  include_children = true          │     └───────────────────┘
   │                            │           │  filter (spec.filter)             │
   │ kms (optional)             │           └──────────────┬────────────────────┘
   │  @facets/gcp_kms            │─key CMEK                 │ writer_identity
   └────────────────────────────┘           ┌──────────────▼────────────────────┐
                                             │ google_storage_bucket_iam_member  │
                                             │  storage.objectCreator to writer  │
                                             └───────────────────────────────────┘
```

`include_children = true` is what makes the sink cover descendant **projects**,
not just folder-level events. The folder sink emits a dedicated `writer_identity`
that is granted `objectCreator` on the bucket so it can write objects.

---

## Usage

```yaml
kind: gcp_log_sink
flavor: standard
version: "1.0"
spec:
  bucket_name: my-audit-bucket        # globally unique GCS bucket name
  sink_name: my-folder-audit-sink
  location: asia-south1
  retention_days: 400
  lock_retention: false               # true irreversibly locks the policy
  filter: ""                          # empty => all folder + descendant logs
  kms_key_name: audit                 # key name in the optional kms input
```

Wire the optional `kms` input to a `@facets/gcp_kms` output to encrypt the bucket
with CMEK; `kms_key_name` selects which key from that key ring's `key_ids` map.

---

## Inputs

| Input | Type | Required | Purpose |
|-------|------|----------|---------|
| `cloud_account` | `@facets/gcp_org_account` | Yes | GCP org account; supplies the `google` provider. |
| `folder` | `@facets/gcp_folder` | Yes | Folder the sink is scoped to; its `folder_id` is the sink parent. |
| `project` | `@facets/gcp_project` | Yes | Project that holds the audit bucket. |
| `kms` | `@facets/gcp_kms` | No | When set, the bucket is CMEK-encrypted with `key_ids[kms_key_name]`. |

---

## Spec

| Field | Required | Default | Notes |
|-------|----------|---------|-------|
| `bucket_name` | Yes | — | Globally unique GCS bucket name. Pattern `^[a-z0-9][a-z0-9._-]{1,61}[a-z0-9]$`. |
| `sink_name` | Yes | — | Cloud Logging folder sink name. |
| `location` | No | `asia-south1` | GCS bucket location. |
| `retention_days` | No | `400` | Days to retain audit objects (min 1). Stored as `days × 86400` seconds. |
| `lock_retention` | No | `false` | When true, irreversibly locks the bucket retention policy. |
| `filter` | No | `""` | Cloud Logging filter. Empty captures all matching folder + descendant project logs. |
| `kms_key_name` | No | `audit` | Key name from the `kms` input used for bucket CMEK. |

---

## Outputs — `@facets/gcp_log_sink`

No interfaces. Attributes (from `outputs.tf`):

| Attribute | Description |
|-----------|-------------|
| `bucket_name` | Audit bucket name. |
| `bucket_url` | Audit bucket URL. |
| `sink_name` | Folder sink name. |
| `writer_identity` | Sink writer service account, granted `objectCreator` on the bucket. |
| `retention_days` | Configured retention in days. |
| `retention_locked` | Whether the retention policy is locked. |

---

## Notes

- **Bucket is not force-destroyed.** `force_destroy = false`, so the bucket
  cannot be deleted while it holds objects. Combined with `versioning` and a
  `retention_policy`, this is intentional evidence protection.
- **`lock_retention` is irreversible.** Once locked, the retention policy cannot
  be shortened or removed — set it only when the retention period is final.
- **Aggregated across descendant projects.** `include_children = true` captures
  logs from every project under the folder; an empty `filter` captures all of
  them.
- **No `unique_writer_identity` argument.** Folder sinks always get a dedicated
  writer identity implicitly — that argument exists only on project sinks.
- **CMEK is optional and conditional.** The `encryption` block is emitted only
  when the `kms` input is wired; otherwise the bucket uses Google-managed keys.
