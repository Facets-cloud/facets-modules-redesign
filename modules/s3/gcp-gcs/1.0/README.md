# S3 — Google Cloud Storage Bucket

Provisions a **Google Cloud Storage bucket** for the generic Facets
object-storage (`s3`) intent. The bucket is created with a **customer-managed
encryption key (CMEK)**, uniform bucket-level access, and public-access
prevention enforced by default. Versioning, lifecycle rules, CORS, labels, and a
retention policy are all optional. It is exposed as a `@facets/bucket` output.

- **Clouds:** gcp
- **Resources created:** `google_storage_bucket.this`
- **Output type:** `@facets/bucket`

---

## Architecture

```
   INPUT                                RESOURCE (main.tf)                    OUTPUT
   ─────────────────────────           ──────────────────────────           ──────────────────

   cloud_account ──────────┐           google_storage_bucket.this           @facets/bucket
   @facets/gcp_cloud_account            name = <instance>-<project_id>        attributes
     project_id            │  project     (truncated to 63)                    bucket_name
     region      ──────────┼─ location  location, storage_class               resource_name
                           │            uniform_bucket_level_access = true       (projects/_/buckets/<name>)
   spec.kms_key_name ──────┘            public_access_prevention              region
     (CMEK, required)      CMEK         encryption.default_kms_key_name       read_grant  (objectViewer)
                                        versioning                            write_grant (objectAdmin)
                                        lifecycle_rule (dynamic)
                                        cors           (dynamic)             interfaces.default
                                        retention_policy (dynamic)            name
```

---

## Usage

```yaml
kind: s3
flavor: gcp-gcs
version: "1.0"
spec:
  kms_key_name: projects/my-project/locations/asia-south1/keyRings/my-cmek/cryptoKeys/storage
  location: asia-south1
  storage_class: STANDARD
  versioning_enabled: false
  public_access_prevention: enforced
  force_destroy: false
  cors_rules: []
  lifecycle_rules: []
  labels: {}
```

---

## Inputs

| Input | Type | Required | Purpose |
|-------|------|----------|---------|
| `cloud_account` | `@facets/gcp_cloud_account` | Yes | Supplies the GCP `project_id` (used in the bucket name and as the project) and the fallback `region` for the bucket location. Provides the `google` provider. |

## Spec

| Field | Type / Enum | Default | Notes |
|-------|-------------|---------|-------|
| `kms_key_name` | string (CMEK path) | — (**required**) | Full CMEK key path (`projects/…/cryptoKeys/…`) set as the bucket default encryption key. |
| `location` | string | cloud account region, else `asia-south1` | Bucket location. Empty falls back to the cloud account region. |
| `storage_class` | `STANDARD` / `NEARLINE` / `COLDLINE` / `ARCHIVE` | `STANDARD` | Default storage class for new objects. |
| `versioning_enabled` | boolean | `false` | Preserve object versions. |
| `public_access_prevention` | `inherited` / `enforced` | `enforced` | Keep `enforced` unless public buckets are explicitly required. |
| `force_destroy` | boolean | `false` | Allow Terraform to delete a non-empty bucket. Keep `false` in production. |
| `lifecycle_rules` | list | `[]` | Each rule: `action` (`Delete` or `SetStorageClass` + `storage_class`) and a `condition` (`age`, `created_before`, `num_newer_versions`). |
| `cors_rules` | list | `[]` | Each rule: `origin`, `method` (GET/HEAD/POST/PUT/DELETE/OPTIONS), `response_header`, `max_age_seconds` (default 3600). |
| `retention_policy` | object | unset | `retention_period_seconds` (required within the block) and `is_locked` (default false). |
| `labels` | object | `{}` | Additional bucket labels. |

## Outputs — `@facets/bucket`

### Attributes

| Field | Value |
|-------|-------|
| `bucket_name` | The GCS bucket name |
| `resource_name` | `projects/_/buckets/<bucket_name>` |
| `region` | The bucket location |
| `read_grant` | `roles/storage.objectViewer` |
| `write_grant` | `roles/storage.objectAdmin` |

### Interfaces

`default.name` — the bucket name.

---

## Notes

- **CMEK is required.** `kms_key_name` is a required spec field and is set as the
  bucket's `default_kms_key_name`. Terraform only passes the key string; the GCS
  service agent must have permission to use it. This satisfies an org policy that
  enforces `gcp.restrictNonCmekServices` for `storage.googleapis.com`.
- **Uniform bucket-level access is always on** (`uniform_bucket_level_access =
  true`) — object ACLs are disabled; access is via IAM only.
- **Public access is prevented by default** (`public_access_prevention =
  enforced`). Change to `inherited` only when a public bucket is intended.
- **Bucket name** is `<instance_name>-<project_id>`, truncated to 63 characters.
- **`retention_policy` is optional and locking is irreversible.** The
  `retention_policy` block renders only when `retention_period_seconds` is set;
  `is_locked` defaults to `false` because locking cannot be undone.
- **`force_destroy` guards deletion of non-empty buckets.** Left `false`, a
  bucket with objects cannot be destroyed by Terraform.
- **Lifecycle `storage_class`** is passed only for `SetStorageClass` actions;
  `Delete` actions send no storage class.
