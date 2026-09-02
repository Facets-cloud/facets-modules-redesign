terraform {
  required_version = ">= 1.0"
}

resource "google_storage_bucket" "this" {
  name                        = local.bucket_name
  project                     = local.project_id
  location                    = local.location
  storage_class               = local.storage_class
  force_destroy               = local.force_destroy
  uniform_bucket_level_access = true
  public_access_prevention    = local.public_access_prevention
  labels                      = local.labels

  # Default CMEK for the bucket. Terraform only passes this string; the GCS
  # service agent handles KMS usage. Required where an org policy enforces
  # gcp.restrictNonCmekServices for storage.googleapis.com.
  encryption {
    default_kms_key_name = local.kms_key_name
  }

  versioning {
    enabled = local.versioning_enabled
  }

  dynamic "lifecycle_rule" {
    for_each = local.lifecycle_rules

    content {
      action {
        type          = lifecycle_rule.value.action.type
        storage_class = lifecycle_rule.value.action.type == "SetStorageClass" ? lifecycle_rule.value.action.storage_class : null
      }

      condition {
        age                = lookup(lifecycle_rule.value.condition, "age", null)
        created_before     = lookup(lifecycle_rule.value.condition, "created_before", null)
        num_newer_versions = lookup(lifecycle_rule.value.condition, "num_newer_versions", null)
      }
    }
  }

  dynamic "cors" {
    for_each = local.cors_rules

    content {
      origin          = lookup(cors.value, "origin", [])
      method          = lookup(cors.value, "method", [])
      response_header = lookup(cors.value, "response_header", [])
      max_age_seconds = lookup(cors.value, "max_age_seconds", 3600)
    }
  }

  dynamic "retention_policy" {
    for_each = local.retention_policy == null ? [] : [local.retention_policy]

    content {
      retention_period = retention_policy.value.retention_period_seconds
      is_locked        = lookup(retention_policy.value, "is_locked", false)
    }
  }
}
