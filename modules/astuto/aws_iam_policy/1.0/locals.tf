# Define your locals here

locals {
  spec     = lookup(var.instance, "spec", {})
  advanced = lookup(var.instance, "advanced", {})

  # Policy document from spec
  policy = local.spec.policy

  # Advanced IAM policy options
  advanced_iam_policy = lookup(local.advanced, "aws_iam_policy", {})
  policy_path         = lookup(local.spec, "path", "/")
  policy_description  = lookup(local.spec, "description", null)

  # Tags: merge environment tags with user-defined tags from spec
  user_defined_tags = lookup(local.spec, "tags", {})
  tags              = merge(var.environment.cloud_tags, local.user_defined_tags)
}

# Output attributes and interfaces
locals {
  output_attributes = {
    arn    = aws_iam_policy.iam_policy.arn
    name   = aws_iam_policy.iam_policy.name
    policy = aws_iam_policy.iam_policy.policy
  }

  output_interfaces = {}
}
