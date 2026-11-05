locals {
  spec  = lookup(var.instance, "spec", {})
  items = lookup(local.spec, "service_accounts", {})
}
