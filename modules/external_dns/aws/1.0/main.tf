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

module "helm_name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 53
  globally_unique = false
  resource_name   = var.instance_name
  resource_type   = "externaldns"
  is_k8s          = true
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
        Effect = "Allow"
        Action = [
          "route53:ListHostedZones",
          "route53:ListHostedZonesByName"
        ]
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

# Deploy external-dns Helm chart
resource "helm_release" "external_dns" {
  depends_on       = [kubernetes_secret.external_dns_r53_secret]
  name             = module.helm_name.name
  chart            = local.chart_source
  repository       = local.chart_repository
  version          = local.helm_version
  namespace        = local.namespace
  create_namespace = false
  cleanup_on_fail  = local.cleanup_on_fail
  wait             = local.wait
  atomic           = local.atomic
  timeout          = local.timeout
  recreate_pods    = local.recreate_pods

  values = [
    yamlencode({
      # Provider configuration
      provider = "aws"
      policy   = "sync"

      # Domain filters
      domainFilters = local.domain_filters

      # TXT record configuration
      txtOwnerId = "${module.helm_name.name}-${var.environment.unique_name}"
      txtSuffix  = var.environment.unique_name

      # Service account configuration
      serviceAccount = {
        create = true
        name   = module.helm_name.name
      }

      # Image configuration (official external-dns image from registry.k8s.io)
      # The kubernetes-sigs chart doesn't properly construct image from registry+repository+tag
      # Use full image path in repository field (matches manual fix that worked)
      image = {
        repository = "${local.image_registry}/${local.image_repository}"
        tag        = local.image_tag != "" ? local.image_tag : "v0.14.2"
        pullPolicy = "IfNotPresent"
        # Ensure registry is not set separately (chart might use it incorrectly)
      }

      # Resource limits
      resources = {
        limits = {
          cpu    = "500m"
          memory = "500Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "100Mi"
        }
      }

      # Metrics configuration
      metrics = {
        serviceMonitor = {
          enabled = true
        }
      }

      # AWS credentials via environment variables
      # The external-dns AWS provider uses the AWS SDK which reads credentials from environment variables
      env = [
        {
          name = "AWS_ACCESS_KEY_ID"
          valueFrom = {
            secretKeyRef = {
              name = local.secret_name
              key  = "access-key-id"
            }
          }
        },
        {
          name = "AWS_SECRET_ACCESS_KEY"
          valueFrom = {
            secretKeyRef = {
              name = local.secret_name
              key  = "secret-access-key"
            }
          }
        },
        {
          name  = "AWS_REGION"
          value = local.aws_region
        }
      ]

      # AWS provider configuration
      aws = {
        region   = local.aws_region
        zoneType = local.zone_type
      }

      # Node scheduling
      nodeSelector = local.node_selector
      tolerations  = local.tolerations

      # Priority class
      priorityClassName = local.priority_class_name
    }),
    yamlencode(local.user_supplied_helm_values)
  ]
}
