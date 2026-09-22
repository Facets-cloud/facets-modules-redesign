# ── Argo Rollouts ───────────────────────────────────────────────────────────

locals {
  rollouts_defaults = {
    controller = {
      nodeSelector = local.node_selector
      tolerations  = local.tolerations
    }
    dashboard = {
      nodeSelector = local.node_selector
      tolerations  = local.tolerations
    }
  }

  # Same shallow-merge trap as helm-events.tf, on two keys here: a
  # custom_values {controller:{replicas:2}} would drop the controller's
  # nodeSelector and tolerations entirely. Merge one level per top-level key.
  rollouts_sources = [local.rollouts_defaults, local.rollouts_values]

  rollouts_merged = jsondecode(join("", [
    "{",
    join(",", [
      for k, v in merge(local.rollouts_sources...) :
      "${jsonencode(k)}:${
        can(keys(v))
        ? jsonencode(merge([
          for src in local.rollouts_sources : lookup(src, k, {})
          if can(keys(lookup(src, k, {})))
        ]...))
        : jsonencode(v)
      }"
    ]),
    "}",
  ]))
}

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

  values = [yamlencode(local.rollouts_merged)]
}
