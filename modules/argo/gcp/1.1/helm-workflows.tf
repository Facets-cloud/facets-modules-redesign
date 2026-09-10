# ── Argo Workflows ──────────────────────────────────────────────────────────

resource "helm_release" "workflows" {
  count      = local.workflows_enabled ? 1 : 0
  name       = "argo-workflows"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-workflows"
  version    = local.workflows_version
  namespace  = "argocd"

  create_namespace = true
  wait             = true
  timeout          = 300

  values = [yamlencode(merge({
    # When create_service_account=false the serviceAccount override is omitted
    # entirely, so the argo-workflows chart keeps its own default controller SA
    # (with its RBAC) and this module does NOT create a k8s ServiceAccount.
    controller = merge({
      nodeSelector = local.node_selector
      tolerations  = local.tolerations
      }, local.workflows_create_sa ? {
      serviceAccount = {
        annotations = local.workflows_enabled ? {
          "iam.gke.io/gcp-service-account" = google_service_account.workflows[0].email
        } : {}
        create = true
        name   = local.workflows_sa_name
      }
    } : {})
    crds = {
      upgradeJob = {
        nodeSelector = local.node_selector
        tolerations  = local.tolerations
      }
    }
    server = {
      nodeSelector = local.node_selector
      tolerations  = local.tolerations
    }
  }, local.workflows_values))]

  depends_on = [
    google_service_account_iam_member.workflows_wi,
    kubernetes_namespace_v1.workflows
  ]
}
