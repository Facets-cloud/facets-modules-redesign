terraform {
  required_version = ">= 1.0"
}

resource "google_storage_bucket" "audit" {
  name                        = var.instance.spec.bucket_name
  project                     = var.inputs.project.attributes.project_id
  location                    = local.location
  uniform_bucket_level_access = true
  force_destroy               = false

  versioning {
    enabled = true
  }

  retention_policy {
    retention_period = local.retention_seconds
    is_locked        = local.retention_locked
  }

  dynamic "encryption" {
    for_each = lookup(var.inputs, "kms", null) == null ? [] : [1]

    content {
      default_kms_key_name = var.inputs.kms.attributes.key_ids[local.kms_key_name]
    }
  }
}

resource "google_logging_folder_sink" "this" {
  name   = var.instance.spec.sink_name
  folder = var.inputs.folder.attributes.folder_id
  # include_children is what makes this cover descendant PROJECTS, not just
  # folder-level events. Without it the sink is near-useless.
  include_children = true
  destination      = "storage.googleapis.com/${google_storage_bucket.audit.name}"
  filter           = local.filter
  # NOTE: no unique_writer_identity here — that argument exists on
  # google_logging_project_sink, not on folder sinks, which always get a
  # dedicated writer identity implicitly.
}

resource "google_storage_bucket_iam_member" "sink_writer" {
  bucket = google_storage_bucket.audit.name
  role   = "roles/storage.objectCreator"
  member = google_logging_folder_sink.this.writer_identity
}
