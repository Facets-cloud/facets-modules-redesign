locals {
  spec          = lookup(var.instance, "spec", {})
  metadata      = lookup(var.instance, "metadata", {})
  metadata_name = lookup(local.metadata, "name", "")
  tags          = merge(var.environment.cloud_tags, lookup(local.spec, "tags", {}))
  region        = var.inputs.cloud_account.attributes.aws_region
}