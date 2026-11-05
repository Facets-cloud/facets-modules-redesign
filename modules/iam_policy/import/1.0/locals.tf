# Import-faithful IAM policy: name/path/policy-document/tags driven by the live spec
# (pushed as an env override) so a plan against the live policy is 0-change.
locals {
  spec = var.instance.spec
  p    = local.spec.policy_config
}
