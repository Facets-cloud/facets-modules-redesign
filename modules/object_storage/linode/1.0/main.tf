# Linode Object Storage Module
# Creates an S3-compatible bucket and a scoped access key.

module "name" {
  source        = "github.com/Facets-cloud/facets-utility-modules//name"
  environment   = var.environment
  limit         = 63
  resource_name = var.instance_name
  resource_type = "bucket"
}

locals {
  # Bucket labels must be lowercase and DNS-compatible.
  bucket_label = lower(replace(module.name.name, "_", "-"))
}

resource "linode_object_storage_bucket" "bucket" {
  region       = var.instance.spec.region
  label        = local.bucket_label
  acl          = var.instance.spec.acl
  cors_enabled = var.instance.spec.cors_enabled
  versioning   = var.instance.spec.versioning_enabled
}

resource "linode_object_storage_key" "key" {
  label = "${local.bucket_label}-key"

  bucket_access {
    bucket_name = linode_object_storage_bucket.bucket.label
    region      = var.instance.spec.region
    permissions = "read_write"
  }
}
