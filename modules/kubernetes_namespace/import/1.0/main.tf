locals {
  spec       = lookup(var.instance, "spec", {})
  namespaces = lookup(local.spec, "namespaces", {})
}

# Namespaces adopted from live.
# NOTE: kubernetes.io/metadata.name is auto-injected and managed by the NamespaceLifecycle admission
# controller on every namespace; the API always returns it, so it is ignored to avoid a perpetual diff.
resource "kubernetes_namespace_v1" "namespace" {
  for_each = local.namespaces

  metadata {
    name        = each.key
    labels      = lookup(lookup(each.value, "metadata", {}), "labels", null)
    annotations = lookup(lookup(each.value, "metadata", {}), "annotations", null)
  }

  lifecycle {
    ignore_changes = [metadata[0].labels["kubernetes.io/metadata.name"]]
  }
}
