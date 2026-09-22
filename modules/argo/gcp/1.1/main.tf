# Module: argo/gcp/1.0
#
# Deploys the full Argo stack on GKE:
# ArgoCD, Argo Workflows, Argo Events, Argo Rollouts
# + Workload Identity for Workflows SA

module "gsa_name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 30
  resource_name   = var.instance_name
  resource_type   = "argo"
  globally_unique = false
}

# Create the workflows namespace for Argo Workflows
resource "kubernetes_namespace_v1" "workflows" {
  metadata {
    name = "workflows"
    labels = {
      "app.kubernetes.io/name"       = "argo-workflows"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }
}
