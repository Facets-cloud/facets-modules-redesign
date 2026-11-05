locals {
  spec       = lookup(var.instance, "spec", {})
  configmaps = lookup(local.spec, "configmaps", {})
}
