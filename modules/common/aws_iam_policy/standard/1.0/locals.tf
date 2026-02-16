# Module logic locals
locals {
  spec = var.instance.spec

  iam_policy = lookup(local.spec, "aws_iam_policy", {})

  # IAM Policy configuration
  policy_name = local.spec.name
  policy      = local.spec.policy

  # Tags
  user_defined_tags = try(local.spec.tags, {})
  tags              = merge(var.environment.cloud_tags, local.user_defined_tags)
}
