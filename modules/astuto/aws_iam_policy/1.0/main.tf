# Define your terraform resources here

module "iam-policy-name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  is_k8s          = false
  globally_unique = true
  resource_name   = var.instance_name
  resource_type   = "iam_policy"
  limit           = 60
  environment     = var.environment
}

resource "aws_iam_policy" "iam_policy" {
  name        = module.iam-policy-name.name
  path        = local.policy_path
  description = local.policy_description
  tags        = local.tags
  policy      = jsonencode(local.policy)

  lifecycle {
    ignore_changes = [name]
  }
}
