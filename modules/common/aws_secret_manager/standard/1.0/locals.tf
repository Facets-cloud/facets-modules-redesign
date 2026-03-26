# Define your locals here
locals {
  metadata                = lookup(var.instance, "metadata", {})
  spec                    = lookup(var.instance, "spec", {})
  user_defined_tags       = lookup(local.metadata, "tags", {})
  override_default_name   = lookup(local.spec, "override_default_name", false)
  override_name           = lookup(local.spec, "override_name", "")
  description             = lookup(local.spec, "description", null)
  kms_key_id              = lookup(local.spec, "kms_key_id", null)
  policy                  = lookup(local.spec, "policy", null)
  recovery_window_in_days = lookup(local.spec, "recovery_window_in_days", null)
  rotation                = lookup(local.spec, "rotation", {})
  rotation_enabled        = lookup(local.rotation, "enabled", false)
  rotation_lambda_arn     = lookup(local.rotation, "lambda_arn", null)
  rotation_rules          = lookup(local.rotation, "rotation_rules", {})
  rotate_immediately      = lookup(local.rotation, "rotate_immediately", false)
  secrets                 = lookup(local.spec, "secrets", {})
}
