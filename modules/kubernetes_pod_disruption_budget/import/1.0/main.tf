resource "kubernetes_pod_disruption_budget_v1" "main" {
  for_each = local.items
  metadata {
    name        = each.value.name
    namespace   = each.value.namespace
    labels      = lookup(each.value, "labels", null)
    annotations = lookup(each.value, "annotations", null)
  }
  spec {
    max_unavailable = lookup(each.value, "max_unavailable", null)
    min_available   = lookup(each.value, "min_available", null)
    selector {
      match_labels = lookup(each.value, "match_labels", null)
    }
  }
}
