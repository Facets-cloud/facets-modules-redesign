# Name generation for IAM resources
module "iam_user_name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 64
  globally_unique = false
  resource_name   = local.cluster_name
  resource_type   = "external-dns"
  is_k8s          = false
}

module "iam_policy_name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 128
  globally_unique = false
  resource_name   = local.cluster_name
  resource_type   = "external-dns-policy"
  is_k8s          = false
}

# IAM User for Route53 access
resource "aws_iam_user" "external_dns_user" {
  name = lower(module.iam_user_name.name)
  tags = merge(var.environment.cloud_tags, {
    Name      = "external-dns-${local.cluster_name}"
    Purpose   = "Route53 DNS management"
    ManagedBy = "facets"
  })
}

# IAM Policy for Route53 permissions
resource "aws_iam_user_policy" "external_dns_r53_policy" {
  name = lower(module.iam_policy_name.name)
  user = aws_iam_user.external_dns_user.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "route53:GetChange"
        Resource = "arn:aws:route53:::change/*"
      },
      {
        Effect = "Allow"
        Action = [
          "route53:ChangeResourceRecordSets",
          "route53:ListResourceRecordSets"
        ]
        Resource = "arn:aws:route53:::hostedzone/${local.hosted_zone_id}"
      },
      {
        Effect   = "Allow"
        Action   = "route53:ListHostedZonesByName"
        Resource = "*"
      }
    ]
  })
}

# IAM Access Key
resource "aws_iam_access_key" "external_dns_access_key" {
  user = aws_iam_user.external_dns_user.name
}

# Kubernetes namespace for external-dns
resource "kubernetes_namespace" "namespace" {
  metadata {
    name = local.namespace
  }
}

# Kubernetes secret with Route53 credentials
resource "kubernetes_secret" "external_dns_r53_secret" {
  depends_on = [kubernetes_namespace.namespace]
  metadata {
    name      = local.secret_name
    namespace = local.namespace
  }
  data = {
    "access-key-id"     = aws_iam_access_key.external_dns_access_key.id
    "secret-access-key" = aws_iam_access_key.external_dns_access_key.secret
  }
}
