# Define your locals here
locals {
  spec            = lookup(var.instance, "spec", {})
  advanced_config = lookup(lookup(var.instance, "advanced", {}), "k8s", {})
  namespace       = var.environment.namespace
}
