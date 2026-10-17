# Import-faithful IAM role: role attributes + attached managed-policy ARNs driven
# by the live spec (pushed as an env override) so a plan against the live role is
# 0-change. Attachments key by policy ARN (stable, matches the import id role/arn).
locals {
  spec        = var.instance.spec
  r           = local.spec.role
  policy_arns = toset(lookup(local.spec, "policy_arns", []))
}
