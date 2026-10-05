locals {
  spec     = lookup(var.instance, "spec", {})
  releases = lookup(local.spec, "releases", {})
}

# Live Facets `service` resources are Helm releases of the vendored app-chart (the legacy
# facets-iac application wrapper). Release name/namespace/chart-name/version match live so the
# import is 0-replace; the multi-element values list is pushed verbatim (base64-encoded so any
# literal ${...} in the payload survives Facets expression interpolation). The helm provider
# never reads values back on import, so the first plan shows a structural `+ values` only.
resource "helm_release" "app_chart" {
  for_each = local.releases

  name             = each.value.name
  namespace        = each.value.namespace
  chart            = "${path.module}/charts/app-chart"
  version          = "0.3.0"
  create_namespace = false
  max_history      = 10
  wait             = false
  atomic           = false
  timeout          = 300
  cleanup_on_fail  = true

  # values_b64 holds base64(JSON array of the verbatim live values strings), reproducing the exact
  # multi-file values list the running release carries.
  values = [for s in jsondecode(base64decode(each.value.values_b64)) : s]

  # Helm provider never reads values/flags back on import, so an adopted release drifts forever on
  # values, chart and the operational flags. Adopt-only: ignore them all (Treebo helm/treebo pattern).
  lifecycle {
    ignore_changes = [
      values, chart, version, repository,
      create_namespace, max_history, wait, cleanup_on_fail, atomic, timeout, name,
    ]
  }
}
