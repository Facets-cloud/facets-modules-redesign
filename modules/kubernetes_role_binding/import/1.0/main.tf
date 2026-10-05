resource "kubernetes_role_binding_v1" "main" {
  for_each = local.items
  metadata {
    name        = each.value.name
    namespace   = each.value.namespace
    labels      = lookup(each.value, "labels", null)
    annotations = lookup(each.value, "annotations", null)
  }
  role_ref {
    api_group = each.value.role_ref[0].api_group
    kind      = each.value.role_ref[0].kind
    name      = each.value.role_ref[0].name
  }
  dynamic "subject" {
    for_each = lookup(each.value, "subject", [])
    content {
      api_group = lookup(subject.value, "api_group", null)
      kind      = subject.value.kind
      name      = subject.value.name
      namespace = lookup(subject.value, "namespace", null)
    }
  }
}
