
locals {
  spec            = lookup(var.instance, "spec", {})
  advanced_config = lookup(lookup(var.instance, "advanced", {}), "k8s", {})
  namespace       = var.environment.namespace
}

resource "kubernetes_config_map_v1" "facets_configmap" {
  metadata {
    name      = lower(var.instance_name)
    namespace = local.namespace
  }

  data = {
    for k, v in lookup(local.spec, "data", {}) : v.key => v.value
  }
}
