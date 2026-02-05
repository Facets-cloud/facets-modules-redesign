# Define your terraform resources here

module "aws_iam_role_name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  is_k8s          = false
  globally_unique = true
  resource_name   = local.name
  resource_type   = "aws_iam_role"
  limit           = 50
  environment     = var.environment
}

module "iam_eks_role" {
  count                 = length(local.irsa) > 0 ? 1 : 0
  source                = "github.com/Facets-cloud/facets-utility-modules//aws_irsa"
  iam_role_name         = module.aws_iam_role_name.name
  iam_arns              = [for k, v in local.policies : v.arn]
  namespace             = local.namespace
  sa_name               = local.service_accounts_list
  eks_oidc_provider_arn = var.inputs.eks_cluster.attributes.oidc_provider_arn
}
