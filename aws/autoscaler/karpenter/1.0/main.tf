locals {
  karpenter_namespace       = "kube-system"
  karpenter_service_account = "karpenter"
  cluster_name              = var.inputs.kubernetes_details.attributes.cluster_name
  oidc_provider_arn         = var.inputs.kubernetes_details.attributes.oidc_provider_arn
  oidc_provider             = var.inputs.kubernetes_details.attributes.oidc_provider
  aws_region                = var.inputs.cloud_account.attributes.aws_region
  node_security_group_id    = var.inputs.kubernetes_details.attributes.node_security_group_id

  # Merge environment tags with instance tags
  instance_tags = merge(
    var.environment.cloud_tags,
    lookup(var.instance.spec, "tags", {}),
    {
      "facets:instance_name" = var.instance_name
      "facets:environment"   = var.environment.name
      "facets:component"     = "karpenter"
    }
  )
}

# IAM Role for Karpenter Controller
resource "aws_iam_role" "karpenter_controller" {
  name = "karpenter-controller-${local.cluster_name}"

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
            "${local.oidc_provider}:sub" = "system:serviceaccount:${local.karpenter_namespace}:${local.karpenter_service_account}"
          }
        }
      }
    ]
  })

  tags = local.instance_tags
}

# IAM Policy for Karpenter Controller
resource "aws_iam_policy" "karpenter_controller" {
  name        = "karpenter-controller-${local.cluster_name}"
  description = "IAM policy for Karpenter controller to manage EC2 instances"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Karpenter"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ec2:DescribeImages",
          "ec2:RunInstances",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeLaunchTemplates",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeInstanceTypeOfferings",
          "ec2:DescribeAvailabilityZones",
          "ec2:DeleteLaunchTemplate",
          "ec2:CreateTags",
          "ec2:CreateLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:DescribeSpotPriceHistory",
          "pricing:GetProducts"
        ]
        Resource = "*"
      },
      {
        Sid    = "ConditionalEC2Termination"
        Effect = "Allow"
        Action = [
          "ec2:TerminateInstances"
        ]
        Condition = {
          StringLike = {
            "ec2:ResourceTag/karpenter.sh/nodepool" = "*"
          }
        }
        Resource = "*"
      },
      {
        Sid      = "PassNodeIAMRole"
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = aws_iam_role.karpenter_node.arn
      },
      {
        Sid      = "EKSClusterEndpointLookup"
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = var.inputs.kubernetes_details.attributes.cluster_arn
      },
      {
        Sid    = "AllowScopedInstanceProfileCreationActions"
        Effect = "Allow"
        Action = [
          "iam:CreateInstanceProfile"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:RequestedRegion" = local.aws_region
          }
          StringLike = {
            "aws:RequestTag/kubernetes.io/cluster/${local.cluster_name}" = "owned"
            "aws:RequestTag/topology.kubernetes.io/region"               = "*"
          }
        }
      },
      {
        Sid    = "AllowScopedInstanceProfileTagActions"
        Effect = "Allow"
        Action = [
          "iam:TagInstanceProfile"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_name}" = "owned"
            "aws:ResourceTag/topology.kubernetes.io/region"               = local.aws_region
            "aws:RequestedRegion"                                         = local.aws_region
          }
        }
      },
      {
        Sid    = "AllowScopedInstanceProfileActions"
        Effect = "Allow"
        Action = [
          "iam:AddRoleToInstanceProfile",
          "iam:RemoveRoleFromInstanceProfile",
          "iam:DeleteInstanceProfile"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/kubernetes.io/cluster/${local.cluster_name}" = "owned"
            "aws:ResourceTag/topology.kubernetes.io/region"               = local.aws_region
          }
        }
      },
      {
        Sid      = "AllowInstanceProfileReadActions"
        Effect   = "Allow"
        Action   = "iam:GetInstanceProfile"
        Resource = "*"
      }
    ]
  })

  tags = local.instance_tags
}

# Attach policy to controller role
resource "aws_iam_role_policy_attachment" "karpenter_controller" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

# IAM Role for Karpenter Nodes
resource "aws_iam_role" "karpenter_node" {
  name = "karpenter-node-${local.cluster_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.instance_tags
}

# Attach required policies to node role
resource "aws_iam_role_policy_attachment" "karpenter_node_policies" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ])

  role       = aws_iam_role.karpenter_node.name
  policy_arn = each.value
}

# Create instance profile for nodes
resource "aws_iam_instance_profile" "karpenter_node" {
  name = "karpenter-node-${local.cluster_name}"
  role = aws_iam_role.karpenter_node.name

  tags = local.instance_tags
}

# Deploy Karpenter via Helm
resource "helm_release" "karpenter" {
  namespace        = local.karpenter_namespace
  create_namespace = false
  name             = "karpenter"
  repository       = "oci://public.ecr.aws/karpenter"
  chart            = "karpenter"
  version          = var.instance.spec.karpenter_version
  wait             = true
  timeout          = 600

  values = [
    yamlencode({
      serviceAccount = {
        name = local.karpenter_service_account
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.karpenter_controller.arn
        }
      }
      settings = {
        clusterName       = local.cluster_name
        clusterEndpoint   = var.inputs.kubernetes_details.attributes.cluster_endpoint
        interruptionQueue = var.instance.spec.interruption_handling ? aws_sqs_queue.karpenter_interruption[0].name : ""
      }
      replicas = lookup(var.instance.spec, "karpenter_replicas", 2)
      controller = {
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "1000m"
            memory = "1Gi"
          }
        }
      }
    })
  ]

  depends_on = [
    aws_iam_role_policy_attachment.karpenter_controller
  ]
}

# SQS Queue for Spot Interruption Handling (optional)
resource "aws_sqs_queue" "karpenter_interruption" {
  count = var.instance.spec.interruption_handling ? 1 : 0

  name                      = "karpenter-${local.cluster_name}"
  message_retention_seconds = 300
  sqs_managed_sse_enabled   = true

  tags = local.instance_tags
}

resource "aws_sqs_queue_policy" "karpenter_interruption" {
  count = var.instance.spec.interruption_handling ? 1 : 0

  queue_url = aws_sqs_queue.karpenter_interruption[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventsToSendMessages"
        Effect = "Allow"
        Principal = {
          Service = [
            "events.amazonaws.com",
            "sqs.amazonaws.com"
          ]
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.karpenter_interruption[0].arn
      }
    ]
  })
}

# EventBridge rules for interruption handling
resource "aws_cloudwatch_event_rule" "karpenter_interruption" {
  for_each = var.instance.spec.interruption_handling ? {
    scheduled_change = {
      event_pattern = jsonencode({
        source      = ["aws.health"]
        detail-type = ["AWS Health Event"]
      })
    }
    spot_interruption = {
      event_pattern = jsonencode({
        source      = ["aws.ec2"]
        detail-type = ["EC2 Spot Instance Interruption Warning"]
      })
    }
    rebalance = {
      event_pattern = jsonencode({
        source      = ["aws.ec2"]
        detail-type = ["EC2 Instance Rebalance Recommendation"]
      })
    }
    instance_state_change = {
      event_pattern = jsonencode({
        source      = ["aws.ec2"]
        detail-type = ["EC2 Instance State-change Notification"]
      })
    }
  } : {}

  name        = "karpenter-${local.cluster_name}-${each.key}"
  description = "Karpenter interruption handling for ${each.key}"

  event_pattern = each.value.event_pattern

  tags = local.instance_tags
}

resource "aws_cloudwatch_event_target" "karpenter_interruption" {
  for_each = var.instance.spec.interruption_handling ? {
    scheduled_change      = "scheduled_change"
    spot_interruption     = "spot_interruption"
    rebalance             = "rebalance"
    instance_state_change = "instance_state_change"
  } : {}

  rule      = aws_cloudwatch_event_rule.karpenter_interruption[each.key].name
  target_id = "KarpenterInterruptionQueue"
  arn       = aws_sqs_queue.karpenter_interruption[0].arn
}

# Add Karpenter node role to aws-auth ConfigMap using EKS access entry
# This allows Karpenter-provisioned nodes to join the cluster
resource "aws_eks_access_entry" "karpenter_node" {
  cluster_name  = local.cluster_name
  principal_arn = aws_iam_role.karpenter_node.arn
  type          = "EC2_LINUX"

  depends_on = [
    aws_iam_role.karpenter_node
  ]
}