# Naming module (consistent with existing Facets conventions)
module "aws_iam_role_name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  is_k8s          = false
  globally_unique = true
  resource_name   = local.name
  resource_type   = "aws_iam_role"
  limit           = 50
  environment     = var.environment
}

# AWS IAM Role with GCP Workload Identity Federation trust policy
resource "aws_iam_role" "this" {
  name = module.aws_iam_role_name.name

  # Trust policy: allows the auto-created GCP SA to assume this role
  # via Google's OIDC provider using sts:AssumeRoleWithWebIdentity
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.google_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            # 'sub' = GCP SA unique numeric ID (auto-created)
            "accounts.google.com:sub" = local.gcp_service_account_unique_id
            # 'oaud' = GCP SA email (auto-created)
            "accounts.google.com:oaud" = local.gcp_service_account_email
          }
        }
      }
    ]
  })

  tags = merge(var.environment.cloud_tags, {
    Name      = module.aws_iam_role_name.name
    ManagedBy = "facets"
    Purpose   = "gcp-federation"
  })
}
