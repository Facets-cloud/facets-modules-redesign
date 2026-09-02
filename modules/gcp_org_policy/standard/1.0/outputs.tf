locals {
  output_interfaces = {}
  output_attributes = {
    applied_constraints = keys(google_org_policy_policy.this)
    parent              = local.parent
  }
}
