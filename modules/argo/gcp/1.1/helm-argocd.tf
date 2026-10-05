# ── ArgoCD ──────────────────────────────────────────────────────────────────

locals {
  # Deep merge redis-ha: module defaults + custom_values overrides
  argocd_redis_ha_defaults = {
    nodeSelector = local.node_selector
    tolerations  = local.tolerations
    haproxy = {
      nodeSelector = local.node_selector
      tolerations  = local.tolerations
    }
  }
  argocd_redis_ha_custom = lookup(local.argocd_values, "redis-ha", {})
  argocd_redis_ha        = merge(local.argocd_redis_ha_defaults, local.argocd_redis_ha_custom)

  # Deep merge server: module defaults + custom_values overrides.
  # --insecure makes argocd-server serve plain HTTP — TLS terminates at the
  # istio gateway, so without it the server 307-redirects every request to its
  # own self-signed HTTPS and the UI breaks behind the TLS-terminating listener.
  argocd_server_defaults = {
    extraArgs = ["--insecure"]
  }
  argocd_server_custom = lookup(local.argocd_values, "server", {})
  argocd_server = merge(
    local.argocd_server_defaults,
    local.argocd_server_custom,
    {
      extraArgs = distinct(concat(
        local.argocd_server_defaults.extraArgs,
        lookup(local.argocd_server_custom, "extraArgs", [])
      ))
    }
  )

  # Remove deep-merged keys from custom_values to avoid shallow merge overwrite.
  # repoServer joins this list because shim.tf deep-merges it (the shim's own
  # keys must survive a user-supplied repoServer block).
  argocd_values_without_redis = {
    for k, v in local.argocd_values : k => v
    if k != "redis-ha" && k != "server" && k != "repoServer"
  }
}

resource "helm_release" "argocd" {
  count      = local.argocd_enabled ? 1 : 0
  name       = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = local.argocd_version
  namespace  = local.argocd_namespace

  create_namespace = true
  wait             = true
  timeout          = 600

  values = [yamlencode(merge({
    global = {
      nodeSelector = local.node_selector
      tolerations  = local.tolerations
    }
    server     = local.argocd_server
    "redis-ha" = local.argocd_redis_ha
    # facets-argo-shim install (see shim.tf). Empty when the shim is disabled,
    # so it contributes nothing to the release values.
    repoServer = local.argocd_repo_server
  }, local.argocd_values_without_redis))]

  # Fail fast on a missing or misplaced credentials Secret rather than burning
  # the 600s wait and surfacing it as a Helm timeout. See shim.tf's guard.
  depends_on = [kubernetes_secret_v1.facets_cp_credentials]
}
