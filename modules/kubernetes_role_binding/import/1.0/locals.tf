locals {
  spec  = lookup(var.instance, "spec", {})
  items = lookup(local.spec, "role_bindings", {})
}
