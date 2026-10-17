locals {
  spec       = lookup(var.instance, "spec", {})
  h          = lookup(local.spec, "helm", {})
  values_raw = lookup(local.spec, "values", null)
  # values_b64 = base64(JSON array of the verbatim live values strings). Used when the live release
  # carries a multi-file values list (bitnami mongodb layers 5 override files); base64 so any literal
  # ${...} in the payload survives Facets interpolation. Falls back to the single `values` string.
  values_b64  = lookup(local.spec, "values_b64", null)
  values_list = local.values_b64 != null ? [for s in jsondecode(base64decode(local.values_b64)) : s] : (local.values_raw == null ? [] : [local.values_raw])
}

# Helm release adopted from live. Every argument is driven by the live spec (pushed via env
# override) so chart/version/namespace/values/flags reproduce the running release exactly.
# The helm provider does not read `values` back on import, so the first plan shows `+ values`.
resource "helm_release" "main" {
  name       = lookup(local.h, "name", var.instance_name)
  chart      = lookup(local.h, "vendored", false) ? "${path.module}/charts/${local.h.chart}.tgz" : local.h.chart
  repository = lookup(local.h, "repository", null)
  version    = lookup(local.h, "version", null)
  namespace  = local.h.namespace

  create_namespace = lookup(local.h, "create_namespace", false)
  max_history      = lookup(local.h, "max_history", 0)
  wait             = lookup(local.h, "wait", true)
  cleanup_on_fail  = lookup(local.h, "cleanup_on_fail", false)
  atomic           = lookup(local.h, "atomic", false)
  timeout          = lookup(local.h, "timeout", 300)

  values = local.values_list

  # Helm provider never reads values/flags back on import, so an adopted release drifts forever on
  # values, chart and the operational flags. Adopt-only: ignore them all (Treebo helm/treebo pattern).
  lifecycle {
    ignore_changes = [
      values, chart, version, repository,
      create_namespace, max_history, wait, cleanup_on_fail, atomic, timeout, name,
    ]
  }
}
