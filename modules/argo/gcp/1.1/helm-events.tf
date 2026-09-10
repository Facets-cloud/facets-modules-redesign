# ── Argo Events ─────────────────────────────────────────────────────────────

resource "helm_release" "events" {
  count      = local.events_enabled ? 1 : 0
  name       = "argo-events"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-events"
  version    = local.events_version
  namespace  = local.events_namespace

  create_namespace = true
  wait             = true
  timeout          = 300

  values = [yamlencode(merge({
    controller = {
      nodeSelector = local.node_selector
      tolerations  = local.tolerations
    }
  }, local.events_values))]
}
