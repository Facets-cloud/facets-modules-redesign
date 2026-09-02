terraform {
  required_version = ">= 1.0"
}

resource "google_artifact_registry_repository" "this" {
  project       = local.project_id
  location      = local.location
  repository_id = local.repository_id
  format        = local.format
  description   = local.description
  kms_key_name  = local.kms_input_present ? var.inputs.kms.attributes.key_ids[local.kms_key_name] : null

  # Only meaningful for DOCKER repositories. When true, an existing tag can never
  # be re-pointed at different bytes — v1.2.3 means one immutable digest forever.
  # Incompatible with promotion schemes that MOVE a floating tag between digests;
  # compatible with promoting by copying a digest into a new tag.
  dynamic "docker_config" {
    for_each = local.format == "DOCKER" && local.immutable_tags ? [1] : []

    content {
      immutable_tags = true
    }
  }

  dynamic "cleanup_policies" {
    for_each = local.cleanup_policies

    content {
      id     = cleanup_policies.value.id
      action = cleanup_policies.value.action

      dynamic "condition" {
        for_each = cleanup_policies.value.older_than == "" ? [] : [cleanup_policies.value.older_than]

        content {
          older_than = condition.value
        }
      }

      dynamic "most_recent_versions" {
        for_each = cleanup_policies.value.keep_count == 0 ? [] : [cleanup_policies.value.keep_count]

        content {
          keep_count = most_recent_versions.value
        }
      }
    }
  }
}
