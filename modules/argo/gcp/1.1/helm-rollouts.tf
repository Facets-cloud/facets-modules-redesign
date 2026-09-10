# ── Argo Rollouts ───────────────────────────────────────────────────────────

resource "helm_release" "rollouts" {
  count      = local.rollouts_enabled ? 1 : 0
  name       = "argo-rollouts"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-rollouts"
  version    = local.rollouts_version
  namespace  = "argocd"

  create_namespace = true
  wait             = true
  timeout          = 300

  values = [yamlencode(merge({
    controller = {
      nodeSelector = local.node_selector
      tolerations  = local.tolerations
    }
    dashboard = {
      nodeSelector = local.node_selector
      tolerations  = local.tolerations
    }
  }, local.rollouts_values))]
}
