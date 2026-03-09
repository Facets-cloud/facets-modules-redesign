# Define your terraform resources here

resource "kubernetes_secret_v1" "facets_secret" {
  metadata {
    name      = lower(var.instance_name)
    namespace = local.namespace
  }

  data = {
    for k, v in lookup(local.spec, "data", {}) : v.key => v.value
  }
}
