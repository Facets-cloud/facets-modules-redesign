module "name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 64
  resource_name   = var.instance_name
  resource_type   = "efs-csi-driver"
  globally_unique = false
}

locals {
  metadata                   = lookup(var.instance, "metadata", {})
  name                       = lookup(local.metadata, "name", module.name.name)
  controller_namespace       = "kube-system"
  controller_service_account = "efs-csi-controller-sa"

  oidc_provider_arn = var.inputs.kubernetes_details.attributes.oidc_provider_arn

  size = lookup(var.instance.spec, "size", {})

  controller_cpu    = lookup(lookup(local.size, "controller", {}), "cpu", "100m")
  controller_memory = lookup(lookup(local.size, "controller", {}), "memory", "128Mi")
  node_cpu          = lookup(lookup(local.size, "node", {}), "cpu", "100m")
  node_memory       = lookup(lookup(local.size, "node", {}), "memory", "128Mi")

  instance_tags = merge(
    var.environment.cloud_tags,
    lookup(var.instance.spec, "tags", {}),
    {
      "facets:instance_name" = var.instance_name
      "facets:environment"   = var.environment.name
      "facets:component"     = "aws-efs-csi-driver"
    }
  )

  user_helm_values = lookup(var.instance.spec, "values", {})

  helm_values = {
    controller = {
      serviceAccount = {
        create = true
        name   = local.controller_service_account
        annotations = {
          "eks.amazonaws.com/role-arn" = module.irsa.iam_role_arn
        }
      }
      resources = {
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
        requests = {
          cpu    = local.controller_cpu
          memory = local.controller_memory
        }
      }
      podDisruptionBudget = {
        enabled        = true
        maxUnavailable = 1
      }
    }
    node = {
      serviceAccount = {
        create = false
        name   = local.controller_service_account
      }
      resources = {
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
        requests = {
          cpu    = local.node_cpu
          memory = local.node_memory
        }
      }
    }
  }
}

# IAM Policy for the EFS CSI Driver
resource "aws_iam_policy" "efs_csi_driver" {
  name        = local.name
  path        = "/"
  description = "IAM policy for the AWS EFS CSI Driver"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:DescribeAccessPoints",
          "elasticfilesystem:DescribeFileSystems",
          "elasticfilesystem:DescribeMountTargets",
          "ec2:DescribeAvailabilityZones"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:CreateAccessPoint"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:RequestTag/efs.csi.aws.com/cluster" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:TagResource"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:ResourceTag/efs.csi.aws.com/cluster" = "true"
          }
        }
      },
      {
        Effect   = "Allow"
        Action   = "elasticfilesystem:DeleteAccessPoint"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/efs.csi.aws.com/cluster" = "true"
          }
        }
      }
    ]
  })

  tags = local.instance_tags
}

# IRSA: creates IAM Role with OIDC trust and attaches the policy
module "irsa" {
  source                = "github.com/Facets-cloud/facets-utility-modules//aws_irsa"
  eks_oidc_provider_arn = local.oidc_provider_arn
  iam_role_name         = local.name
  namespace             = local.controller_namespace
  sa_name               = local.controller_service_account
  iam_arns = {
    efs-csi-controller-sa = {
      arn = aws_iam_policy.efs_csi_driver.arn
    }
  }
}

# Deploy the EFS CSI Driver via Helm
resource "helm_release" "efs_csi_driver" {
  depends_on = [module.irsa]

  repository = "https://kubernetes-sigs.github.io/aws-efs-csi-driver/"
  chart      = "aws-efs-csi-driver"
  version    = var.instance.spec.chart_version
  name       = "aws-efs-csi-driver"
  namespace  = local.controller_namespace

  values = [
    yamlencode(local.helm_values),
    yamlencode(local.user_helm_values),
  ]
}
