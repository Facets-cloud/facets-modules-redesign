# Import-faithful DynamoDB: every attribute driven by the live spec (pushed as an
# env override) so a plan against the live table is 0-change. See facets.yaml.
locals {
  spec = var.instance.spec
  t    = local.spec.table
}
