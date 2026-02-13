
locals {
  spec            = lookup(var.instance, "spec", {})
  advanced_config = lookup(lookup(var.instance, "advanced", {}), "k8s", {})
  namespace       = var.environment.namespace
}

module "facets-configmap" {
  source          = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resource"
  name            = lower(var.instance_name)
  namespace       = local.namespace
  advanced_config = {}
  release_name    = "configmap-${var.instance_name}"
  data = {
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name        = lower(var.instance_name)
      namespace   = local.namespace
      annotations = {}
      labels      = {}
    }
    data = {
      for k, v in lookup(local.spec, "data", {}) : v.key => v.value
    }
  }
}
