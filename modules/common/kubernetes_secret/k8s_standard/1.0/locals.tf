# Define your locals here
locals {
  spec      = lookup(var.instance, "spec", {})
  namespace = var.environment.namespace
}
