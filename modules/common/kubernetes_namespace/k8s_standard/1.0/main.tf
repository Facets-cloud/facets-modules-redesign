locals {
  name = coalesce(var.instance.spec.name, lower(var.environment.name))
}

resource "kubernetes_namespace_v1" "this" {
  metadata {
    name = local.name
  }
}
