locals {
  spec          = var.instance.spec
  bucket_name   = "${local.spec.bucket_name}-${var.environment.unique_name}"
  location      = coalesce(local.spec.location, "asia-south1")
  versioning    = coalesce(local.spec.versioning_enabled, true)
  force_destroy = coalesce(local.spec.force_destroy, false)
  storage_class = coalesce(local.spec.storage_class, "STANDARD")

  labels = merge(
    {
      managed_by     = "facets"
      resource_name  = var.instance_name
      environment    = var.environment.name
    },
    var.environment.cloud_tags
  )
}

resource "google_storage_bucket" "this" {
  name          = local.bucket_name
  location      = local.location
  project       = var.inputs.cloud_account.attributes.gcp_project_id
  storage_class = local.storage_class
  force_destroy = local.force_destroy
  labels        = local.labels

  versioning {
    enabled = local.versioning
  }

  uniform_bucket_level_access = true

  lifecycle {
    prevent_destroy = true
  }
}
