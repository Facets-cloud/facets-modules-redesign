# ── Argo Workflows ──────────────────────────────────────────────────────────

locals {
  workflows_defaults = {
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
  }

  # Same shallow-merge trap as helm-events.tf, and the worst instance of it:
  # custom_values collides here on controller, crds AND server, and the
  # controller block carries the Workload Identity serviceAccount annotation.
  # A custom_values {controller:{replicas:2}} would drop that annotation, so
  # Workflows pods would silently lose their GCP identity. Merge one level per
  # top-level key; custom_values still wins on genuine conflicts.
  workflows_sources = [local.workflows_defaults, local.workflows_values]

  workflows_merged = jsondecode(join("", [
    "{",
    join(",", [
      for k, v in merge(local.workflows_sources...) :
      "${jsonencode(k)}:${
        can(keys(v))
        ? jsonencode(merge([
          for src in local.workflows_sources : lookup(src, k, {})
          if can(keys(lookup(src, k, {})))
        ]...))
        : jsonencode(v)
      }"
    ]),
    "}",
  ]))
}

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

  values = [yamlencode(local.workflows_merged)]

  depends_on = [
    google_service_account_iam_member.workflows_wi,
    kubernetes_namespace_v1.workflows
  ]
}
