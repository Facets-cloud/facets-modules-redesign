# ── Outputs ─────────────────────────────────────────────────────────────────

locals {
  output_attributes = {
    argocd_namespace           = local.argocd_enabled ? local.argocd_namespace : ""
    argocd_server_service      = local.argocd_enabled ? "${helm_release.argocd[0].name}-argocd-server" : ""
    workflows_namespace        = local.workflows_enabled ? local.argocd_namespace : ""
    workflows_server_service   = local.workflows_enabled ? "${helm_release.workflows[0].name}-server" : ""
    events_namespace           = local.events_enabled ? local.events_namespace : ""
    rollouts_namespace         = local.rollouts_enabled ? local.argocd_namespace : ""
    rollouts_dashboard_service = local.rollouts_enabled ? "${helm_release.rollouts[0].name}-dashboard" : ""
    workflows_sa_email         = local.workflows_enabled ? google_service_account.workflows[0].email : ""

    # facets-argo-shim state. Consumers that deploy charts containing
    # ${facets:...} references gate on shim_enabled: without the shim those
    # renders fail closed inside ArgoCD, which Terraform cannot otherwise see.
    # Depends on the RBAC resources so the flag only reads true once the grant
    # the resolver actually needs is in place, not merely when the chart values
    # were set.
    shim_enabled = local.shim_enabled && length(kubernetes_role_binding_v1.facets_shim_app_reader) > 0
    shim_version = local.shim_version
  }
  output_interfaces = {}
}
