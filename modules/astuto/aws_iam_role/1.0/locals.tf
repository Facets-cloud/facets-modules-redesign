# Define your locals here

locals {
  name             = lower(var.instance_name)
  spec             = lookup(var.instance, "spec", {})
  advanced         = lookup(var.instance, "advanced", {})
  irsa             = lookup(local.spec, "irsa", {})
  service_accounts = lookup(local.irsa, "service_accounts", [])
  oidc             = lookup(local.irsa, "oidc_providers", {})

  # Namespace with fallback to environment namespace
  namespace = lookup(var.instance, "namespace", null) != null ? var.instance.namespace : (
    lookup(var.environment, "namespace", null) != null ? var.environment.namespace : "default"
  )

  # Service account names as a list of strings
  service_accounts_list = [for sa in local.service_accounts : sa.name]

  # Merge user-provided OIDC providers with the primary EKS OIDC provider
  oidc_providers = merge({
    for k, v in local.oidc : k => {
      provider_arn               = v.arn
      namespace_service_accounts = [for x in local.service_accounts : "${local.namespace}:${x.name}"]
    }
    }, {
    facets = {
      provider_arn               = var.inputs.eks_cluster.attributes.oidc_provider_arn
      namespace_service_accounts = [for x in local.service_accounts : "${local.namespace}:${x.name}"]
    }
  })

  policies              = lookup(local.spec, "policies", {})
  aws_iam_role_advanced = lookup(local.advanced, "aws_iam_role", {})
  user_defined_tags     = lookup(local.aws_iam_role_advanced, "tags", {})
}

# Output attributes and interfaces are defined in outputs.tf via locals
locals {
  output_attributes = {
    iam_role_arn         = length(local.irsa) > 0 ? module.iam_eks_role[0].role_arn : null
    iam_role_name        = length(local.irsa) > 0 ? module.iam_eks_role[0].role_name : null
    k8s_service_accounts = local.service_accounts_list
    namespace            = local.namespace
  }

  output_interfaces = {}
}
