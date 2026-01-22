resource "kubernetes_role_v1" "role" {
  for_each = local.effective_roles

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

resource "kubernetes_cluster_role_v1" "cluster_role" {
  for_each = local.effective_cluster_roles

  metadata {
    name        = each.key
    annotations = lookup(lookup(each.value, "metadata", {}), "annotations", null)
    labels      = lookup(lookup(each.value, "metadata", {}), "labels", null)
  }

  dynamic "rule" {
    for_each = lookup(each.value, "rules", {})
    content {
      api_groups        = lookup(rule.value, "api_groups", null)
      resources         = lookup(rule.value, "resources", null)
      resource_names    = lookup(rule.value, "resource_names", null)
      non_resource_urls = lookup(rule.value, "non_resource_urls", null)
      verbs             = rule.value.verbs
    }
  }
}
