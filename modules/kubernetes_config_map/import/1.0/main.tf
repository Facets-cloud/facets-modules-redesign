# ConfigMaps adopted from live (keyed by "<namespace>/<name>").
# data is delivered base64-encoded (data_b64) because dashboard JSON etc. can contain literal
# ${...} that would otherwise collide with Facets expression interpolation; decoded here.
resource "kubernetes_config_map_v1" "main" {
  for_each = local.configmaps

  metadata {
    name        = each.value.name
    namespace   = each.value.namespace
    labels      = lookup(each.value, "labels", null)
    annotations = lookup(each.value, "annotations", null)
  }

  data = lookup(each.value, "data_b64", null) != null ? {
    for k, v in each.value.data_b64 : k => base64decode(v)
  } : lookup(each.value, "data", null)

  binary_data = lookup(each.value, "binary_data", null)

  # adopt-only: saas-cp stays the live owner until handoff (1155 incident)
  lifecycle {
    ignore_changes = [data, binary_data, metadata[0].annotations, metadata[0].labels]
  }
}
