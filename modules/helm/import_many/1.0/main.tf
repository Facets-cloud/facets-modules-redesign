locals {
  spec     = lookup(var.instance, "spec", {})
  releases = lookup(local.spec, "releases", {})
}

# Bulk true-import of existing Helm releases, keyed by release name. Each release is driven entirely by
# the live spec pushed via env override. Vendored charts (repo=null / local .tgz in live) are referenced
# from charts/ so version resolves from the vendored Chart.yaml and matches live; repo-backed charts keep
# their live repository + pinned version and are pulled at plan time. The helm provider never reads values
# back on import, so the first plan shows a structural `+ values` populate only.
resource "helm_release" "r" {
  for_each = local.releases

  name       = each.value.name
  namespace  = each.value.namespace
  chart      = lookup(each.value, "vendored", false) ? "${path.module}/charts/${each.value.chart}.tgz" : each.value.chart
  repository = lookup(each.value, "vendored", false) ? null : lookup(each.value, "repository", null)
  version    = lookup(each.value, "version", null)

  create_namespace = lookup(each.value, "create_namespace", false)
  max_history      = lookup(each.value, "max_history", 0)
  wait             = lookup(each.value, "wait", true)
  cleanup_on_fail  = lookup(each.value, "cleanup_on_fail", false)
  atomic           = lookup(each.value, "atomic", false)
  timeout          = lookup(each.value, "timeout", 300)

  # values_b64 = base64(JSON array of the verbatim live values strings), base64 so any literal ${...}
  # in the payload survives Facets expression interpolation untouched.
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
