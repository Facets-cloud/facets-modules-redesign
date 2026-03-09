resource "google_secret_manager_secret" "this" {
  for_each = local.all_entries

  secret_id = each.key
  project   = var.inputs.cloud_account.attributes.project_id

  # --------------------------------------------------------------------------
  # Replication Policy (same for all secrets in this resource)
  # --------------------------------------------------------------------------
  replication {
    dynamic "auto" {
      for_each = local.spec.replication.type == "auto" ? [1] : []
      content {
        dynamic "customer_managed_encryption" {
          for_each = lookup(local.spec.replication, "kms_key_name", null) != null ? [1] : []
          content {
            kms_key_name = local.spec.replication.kms_key_name
          }
        }
      }
    }

    dynamic "user_managed" {
      for_each = local.spec.replication.type == "user_managed" ? [1] : []
      content {
        dynamic "replicas" {
          for_each = lookup(local.spec.replication, "replicas", {})
          content {
            location = replicas.value.location
            dynamic "customer_managed_encryption" {
              for_each = lookup(replicas.value, "kms_key_name", null) != null ? [1] : []
              content {
                kms_key_name = replicas.value.kms_key_name
              }
            }
          }
        }
      }
    }
  }

  # --------------------------------------------------------------------------
  # Pub/Sub Topics
  # --------------------------------------------------------------------------
  dynamic "topics" {
    for_each = lookup(local.spec, "topics", {})
    content {
      name = topics.value.name
    }
  }

  # --------------------------------------------------------------------------
  # Rotation Policy
  # --------------------------------------------------------------------------
  dynamic "rotation" {
    for_each = lookup(local.spec, "rotation", null) != null ? [lookup(local.spec, "rotation", null)] : []
    content {
      next_rotation_time = lookup(rotation.value, "next_rotation_time", null)
      rotation_period    = lookup(rotation.value, "rotation_period", null)
    }
  }

  # --------------------------------------------------------------------------
  # Metadata
  # --------------------------------------------------------------------------
  labels      = local.labels
  annotations = lookup(local.spec, "annotations", {})
  expire_time = lookup(local.spec, "expire_time", null)
  ttl         = lookup(local.spec, "ttl", null)
}
