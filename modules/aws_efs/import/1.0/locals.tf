# Import-faithful EFS: every attribute driven by the live spec (pushed as an env
# override) so a plan against the live filesystem is 0-change. See facets.yaml.
locals {
  spec          = var.instance.spec
  fs            = local.spec.file_system
  sg            = local.spec.security_group
  mount_targets = { for m in local.spec.mount_targets : m.subnet_id => m }
}
