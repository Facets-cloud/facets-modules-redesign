# Import-faithful CloudWatch log group: name/retention/kms/tags driven by the live
# spec (pushed as an env override) so a plan against the live log group is 0-change.
locals {
  spec = var.instance.spec
  lg   = local.spec.log_group
}
