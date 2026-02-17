locals {
  controller_namespace       = "kube-system"
  controller_service_account = "aws-load-balancer-controller"
  cluster_name               = var.inputs.eks_details.attributes.cluster_name
  oidc_provider_arn          = var.inputs.eks_details.attributes.oidc_provider_arn
  oidc_provider              = var.inputs.eks_details.attributes.oidc_provider
  vpc_id                     = var.inputs.network_details.attributes.vpc_id
  aws_region                 = var.inputs.cloud_account.attributes.aws_region

  instance_tags = merge(
    var.environment.cloud_tags,
    lookup(var.instance.spec, "tags", {}),
    {
      "facets:instance_name" = var.instance_name
      "facets:environment"   = var.environment.name
      "facets:component"     = "aws-alb-controller"
    }
  )
}

# IAM Role for AWS Load Balancer Controller
resource "aws_iam_role" "alb_controller" {
  name = "aws-lb-controller-${local.cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.oidc_provider}:aud" = "sts.amazonaws.com"
            "${local.oidc_provider}:sub" = "system:serviceaccount:${local.controller_namespace}:${local.controller_service_account}"
          }
        }
      }
    ]
  })

  tags = local.instance_tags
}

# IAM Policy for AWS Load Balancer Controller (official AWS-recommended policy)
resource "aws_iam_policy" "alb_controller" {
  name        = "aws-lb-controller-${local.cluster_name}"
  description = "IAM policy for the AWS Load Balancer Controller"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ELBPermissions"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:DeleteRule",
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:SetWebAcl",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:RemoveTags",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeTags",
          "elasticloadbalancing:AddListenerCertificates",
          "elasticloadbalancing:RemoveListenerCertificates"
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2Permissions"
        Effect = "Allow"
        Action = [
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeVpcs",
          "ec2:DescribeVpcPeeringConnections",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeInstances",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeTags",
          "ec2:DescribeCoipPools",
          "ec2:GetCoipPoolUsage",
          "ec2:DescribeAvailabilityZones",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:CreateTags",
          "ec2:DeleteTags"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMPermissions"
        Effect = "Allow"
        Action = [
          "iam:CreateServiceLinkedRole"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "iam:AWSServiceName" = "elasticloadbalancing.amazonaws.com"
          }
        }
      },
      {
        Sid    = "ACMPermissions"
        Effect = "Allow"
        Action = [
          "acm:DescribeCertificate",
          "acm:ListCertificates"
        ]
        Resource = "*"
      },
      {
        Sid    = "WAFPermissions"
        Effect = "Allow"
        Action = [
          "wafv2:GetWebACL",
          "wafv2:GetWebACLForResource",
          "wafv2:AssociateWebACL",
          "wafv2:DisassociateWebACL"
        ]
        Resource = "*"
      },
      {
        Sid    = "ShieldPermissions"
        Effect = "Allow"
        Action = [
          "shield:GetSubscriptionState",
          "shield:DescribeProtection",
          "shield:CreateProtection",
          "shield:DeleteProtection"
        ]
        Resource = "*"
      },
      {
        Sid    = "CognitoPermissions"
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPoolClient"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.instance_tags
}

# Attach policy to controller role
resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

# Deploy AWS Load Balancer Controller via Helm
resource "helm_release" "alb_controller" {
  namespace        = local.controller_namespace
  create_namespace = false
  name             = "aws-load-balancer-controller"
  repository       = "https://aws.github.io/eks-charts"
  chart            = "aws-load-balancer-controller"
  version          = var.instance.spec.controller_version
  wait             = true
  timeout          = 600

  values = [
    yamlencode({
      clusterName = local.cluster_name
      region      = local.aws_region
      vpcId       = local.vpc_id
      serviceAccount = {
        create = true
        name   = local.controller_service_account
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
        }
      }
      replicaCount = lookup(var.instance.spec, "controller_replicas", 1)
      nodeSelector = {
        "node-role" = "system"
      }
      resources = {
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }
    })
  ]

  depends_on = [
    aws_iam_role_policy_attachment.alb_controller
  ]
}
