locals {
  roles = lookup(local.spec, "roles", {})
}

resource "kubernetes_role_v1" "role" {
  for_each = local.roles

  metadata {
    name        = each.key
    namespace   = lookup(lookup(each.value, "metadata", {}), "namespace", var.environment.namespace)
    annotations = lookup(lookup(each.value, "metadata", {}), "annotations", null)
    labels      = lookup(lookup(each.value, "metadata", {}), "labels", null)
  }

  dynamic "rule" {
    for_each = lookup(each.value, "rules", {})
    content {
      api_groups     = rule.value.api_groups
      resources      = rule.value.resources
      resource_names = lookup(rule.value, "resource_names", null)
      verbs          = rule.value.verbs
    }
  }
}