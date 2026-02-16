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
  path        = try(local.iam_policy, "/")
  description = try(local.iam_policy, null)
  tags        = local.tags
  policy      = jsonencode(local.policy)

  lifecycle {
    ignore_changes = [name]
  }
}
