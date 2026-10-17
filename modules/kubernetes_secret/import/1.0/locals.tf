locals {
  spec    = lookup(var.instance, "spec", {})
  secrets = lookup(local.spec, "secrets", {})
}
