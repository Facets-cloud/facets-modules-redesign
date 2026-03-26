locals {
  spec   = lookup(var.instance, "spec", {})
  tags   = merge(var.environment.cloud_tags, lookup(local.spec, "tags", {}))
  region = var.inputs.cloud_account.attributes.aws_region
}