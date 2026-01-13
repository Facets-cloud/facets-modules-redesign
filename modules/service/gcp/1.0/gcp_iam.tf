locals {
  gcp_cloud_account        = lookup(var.inputs, "gcp_cloud_account", {})
  cloud_account_attributes = lookup(local.gcp_cloud_account, "attributes", {})
  gcp_advanced_config       = lookup(lookup(var.instance, "advanced", {}), "gcp", {})
  gcp_cloud_permissions     = lookup(lookup(local.spec, "cloud_permissions", {}), "gcp", {})
  gcp_iam_arns = lookup(local.gcp_cloud_permissions, "roles", lookup(local.gcp_advanced_config, "iam", {}))
  roles                     = { for key, val in local.gcp_iam_arns : val.role => { role = val.role, condition = lookup(val, "condition", {}) } }
}


module "sr-name" {
  # Create unique name if GCP roles OR AWS IAM ARNs are specified
  count           = local.iam_enabled ? 1 : 0
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  is_k8s          = false
  globally_unique = true
  resource_name   = local.resource_name
  resource_type   = local.resource_type
  limit           = 33
  environment     = var.environment
  prefix          = "a"
}

module "gcp-workload-identity" {
  # Create GCP service account if:
  # 1. GCP IAM roles are specified, OR
  # 2. AWS IAM ARNs are specified (for cross-cloud federation)
  count               = local.iam_enabled ? 1 : 0
  source              = "./gcp_workload-identity/workload-identity"
  name                = module.sr-name.0.name
  k8s_sa_name         = "${local.sa_name}-sa"
  namespace           = local.namespace
  project_id          = local.cluster_project
  roles               = local.roles
  use_existing_k8s_sa = true
  annotate_k8s_sa     = false
}