locals {
  project_id = coalesce(
    try(var.inputs.cloud_account.attributes.project_id, null),
    try(var.inputs.cloud_account.attributes.project, null)
  )
  base_name                = var.instance_name
  bucket_name              = substr("${local.base_name}-${local.project_id}", 0, 63)
  location                 = coalesce(var.instance.spec.location != "" ? var.instance.spec.location : null, try(var.inputs.cloud_account.attributes.region, null), "asia-south1")
  kms_key_name             = var.instance.spec.kms_key_name
  versioning_enabled       = var.instance.spec.versioning_enabled
  force_destroy            = var.instance.spec.force_destroy
  storage_class            = var.instance.spec.storage_class
  lifecycle_rules          = var.instance.spec.lifecycle_rules
  cors_rules               = var.instance.spec.cors_rules
  labels                   = var.instance.spec.labels
  retention_policy         = try(var.instance.spec.retention_policy.retention_period_seconds, null) == null ? null : var.instance.spec.retention_policy
  public_access_prevention = var.instance.spec.public_access_prevention
}
