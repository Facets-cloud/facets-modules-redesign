# Import-faithful Route53 records: zone/name/type/ttl/values driven by the live spec
# (pushed as an env override) so a plan against the live records is 0-change.
locals {
  spec    = var.instance.spec
  records = local.spec.records
}
