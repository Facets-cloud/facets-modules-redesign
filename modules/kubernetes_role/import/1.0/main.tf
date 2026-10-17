resource "kubernetes_role_v1" "main" {
  for_each = local.items
  metadata {
    name        = each.value.name
    namespace   = each.value.namespace
    labels      = lookup(each.value, "labels", null)
    annotations = lookup(each.value, "annotations", null)
  }
  dynamic "rule" {
    for_each = lookup(each.value, "rule", [])
    content {
      api_groups     = lookup(rule.value, "api_groups", null)
      resources      = lookup(rule.value, "resources", null)
      verbs          = rule.value.verbs
      resource_names = lookup(rule.value, "resource_names", null)
    }
  }
}
