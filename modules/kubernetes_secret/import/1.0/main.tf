# Secrets adopted from live (keyed by "<namespace>/<name>").
# data delivered base64-encoded (data_b64) to survive Facets interpolation + special chars; decoded here.
resource "kubernetes_secret_v1" "main" {
  for_each = local.secrets

  metadata {
    name        = each.value.name
    namespace   = each.value.namespace
    labels      = lookup(each.value, "labels", null)
    annotations = lookup(each.value, "annotations", null)
  }

  type = lookup(each.value, "type", "Opaque")

  data = lookup(each.value, "data_b64", null) != null ? {
    for k, v in each.value.data_b64 : k => base64decode(v)
  } : lookup(each.value, "data", null)

  # wait_for_service_account_token is a client-side create flag the API never returns (one-time write
  # on import). annotations on these secrets are operator-managed (cert-manager, SA-token controller,
  # ecr-token refresher) — left to their controllers to avoid a perpetual diff.
  lifecycle {
    ignore_changes = [wait_for_service_account_token, metadata[0].annotations]
  }
}
