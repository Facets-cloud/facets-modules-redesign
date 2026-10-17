locals {
  spec     = lookup(var.instance, "spec", {})
  releases = lookup(local.spec, "releases", {})
  singles  = { for k, v in local.releases : k => v if lookup(v, "chart_kind", "single") == "single" }
  multis   = { for k, v in local.releases : k => v if lookup(v, "chart_kind", "single") == "multi" }
}

# Live Facets k8s_resource objects are Helm releases of the vendored pass-through chart. The single
# chart (dynamic-k8s-resource) renders one manifest from values.resource; the multi chart
# (dynamic-k8s-resources) renders many from values.resources. Release name/namespace/chart-name/version
# match live so the import is 0-replace; values are pushed verbatim (provider shows `+ values` only).
resource "helm_release" "single" {
  for_each = local.singles

  name             = each.value.name
  namespace        = each.value.namespace
  chart            = "${path.module}/charts/dynamic-k8s-resource"
  create_namespace = true
  max_history      = 10
  wait             = false
  atomic           = false
  timeout          = 300
  cleanup_on_fail  = lookup(each.value, "cleanup_on_fail", true)

  # values_b64 holds the verbatim live values, base64-encoded so literal ${...} in the payload
  # (bash in embedded scripts) survives Facets expression interpolation untouched.
  values = [base64decode(each.value.values_b64)]

  # Helm provider never reads values back on import — adopt-only, ignore drift (as the other helm modules do).
  lifecycle {
    ignore_changes = [values, chart, version, create_namespace, max_history, wait, cleanup_on_fail, atomic, timeout, name]
  }
}

resource "helm_release" "multi" {
  for_each = local.multis

  name             = each.value.name
  namespace        = each.value.namespace
  chart            = "${path.module}/charts/dynamic-k8s-resources"
  create_namespace = true
  max_history      = 10
  wait             = false
  atomic           = false
  timeout          = 300
  cleanup_on_fail  = lookup(each.value, "cleanup_on_fail", false)

  values = [base64decode(each.value.values_b64)]

  # Helm provider never reads values back on import — adopt-only, ignore drift (as the other helm modules do).
  lifecycle {
    ignore_changes = [values, chart, version, create_namespace, max_history, wait, cleanup_on_fail, atomic, timeout, name]
  }
}
