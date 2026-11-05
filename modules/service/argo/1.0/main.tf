# service/argo/1.0
#
# Creates one ArgoCD ApplicationSet per blueprint resource. The generated
# Application carries the facets-argo-shim identity annotations, so
# ${facets:...} references inside the deployed chart resolve against this
# project/environment (see locals.tf for the full contract).

# Fails the plan when this service uses ${facets:...} references but the wired
# argo_stack has no shim installed. Without this the release succeeds and the
# failure only surfaces later, inside ArgoCD, as a render error Terraform
# cannot see.
resource "terraform_data" "shim_precondition" {
  input = local.shim_enabled

  lifecycle {
    precondition {
      condition = !local.uses_facets_refs || local.shim_enabled
      error_message = join(" ", [
        "This service uses $${facets:...} references, but the wired argo_stack",
        "reports shim_enabled = false. facets-argo-shim must be installed in",
        "argocd-repo-server or every render containing a reference fails closed",
        "inside ArgoCD. Set spec.argocd.facets_shim.enabled = true on the argo",
        "resource (requires argo/gcp >= 1.1), or remove the references from this",
        "service's values.",
      ])
    }
  }
}

module "name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 63
  resource_name   = var.instance_name
  resource_type   = "service"
  is_k8s          = true
  globally_unique = false
}

module "applicationset" {
  source = "github.com/Facets-cloud/facets-utility-modules//any-k8s-resources"

  name         = local.service_name
  release_name = module.name.name
  namespace    = local.argocd_namespace

  resources_data = {
    applicationset = local.applicationset
  }

  advanced_config = lookup(lookup(var.instance, "advanced", {}), "service", {})
}
