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
  vpc_id            = var.inputs.network_details.attributes.vpc_id
  vpc_cidr_block    = var.inputs.network_details.attributes.vpc_cidr_block
  private_subnets   = var.inputs.network_details.attributes.private_subnet_ids

  aws_efs_file_system = lookup(var.instance.spec, "aws_efs_file_system", {})
  size                = lookup(var.instance.spec, "size", {})

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
    storageClasses = [
      {
        name         = "efs-sc"
        mountOptions = ["tls", "iam"]
        parameters = {
          provisioningMode = "efs-ap"
          fileSystemId     = aws_efs_file_system.efs_csi_driver.id
          directoryPerms   = "700"
        }
        reclaimPolicy     = "Delete"
        volumeBindingMode = "Immediate"
      }
    ]
  }
}

# EFS File System
resource "aws_efs_file_system" "efs_csi_driver" {
  encrypted                       = lookup(local.aws_efs_file_system, "encrypted", true)
  kms_key_id                      = lookup(local.aws_efs_file_system, "kms_key_id", null)
  performance_mode                = lookup(local.aws_efs_file_system, "performance_mode", null)
  creation_token                  = lookup(local.aws_efs_file_system, "creation_token", null)
  availability_zone_name          = lookup(local.aws_efs_file_system, "availability_zone_name", null)
  throughput_mode                 = lookup(local.aws_efs_file_system, "throughput_mode", null)
  provisioned_throughput_in_mibps = lookup(local.aws_efs_file_system, "provisioned_throughput_in_mibps", null)

  dynamic "lifecycle_policy" {
    for_each = lookup(local.aws_efs_file_system, "lifecycle_policy", {})
    content {
      transition_to_ia                    = lookup(lifecycle_policy.value, "transition_to_ia", null)
      transition_to_primary_storage_class = lookup(lifecycle_policy.value, "transition_to_primary_storage_class", null)
    }
  }

  tags = merge(
    local.instance_tags,
    lookup(local.aws_efs_file_system, "tags", {}),
    { Name = local.name }
  )

  lifecycle {
    prevent_destroy = true
  }
}

# Security Group allowing NFS traffic from within the VPC
resource "aws_security_group" "efs_csi_driver" {
  name   = local.name
  vpc_id = local.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "TCP"
    cidr_blocks = [local.vpc_cidr_block]
    description = "NFS inbound access to EFS filesystem ${local.name}"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = local.instance_tags
}

# Mount Targets in each private subnet
resource "aws_efs_mount_target" "efs_csi_driver" {
  count           = length(local.private_subnets)
  file_system_id  = aws_efs_file_system.efs_csi_driver.id
  subnet_id       = local.private_subnets[count.index]
  security_groups = [aws_security_group.efs_csi_driver.id]
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
        Resource = [
          aws_efs_file_system.efs_csi_driver.arn,
          "${aws_efs_file_system.efs_csi_driver.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "elasticfilesystem:CreateAccessPoint"
        ]
        Resource = [
          aws_efs_file_system.efs_csi_driver.arn,
          "${aws_efs_file_system.efs_csi_driver.arn}/*"
        ]
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
        Resource = [
          aws_efs_file_system.efs_csi_driver.arn,
          "${aws_efs_file_system.efs_csi_driver.arn}/*"
        ]
        Condition = {
          StringLike = {
            "aws:ResourceTag/efs.csi.aws.com/cluster" = "true"
          }
        }
      },
      {
        Effect = "Allow"
        Action = "elasticfilesystem:DeleteAccessPoint"
        Resource = [
          aws_efs_file_system.efs_csi_driver.arn,
          "${aws_efs_file_system.efs_csi_driver.arn}/*"
        ]
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

  values = [yamlencode(local.helm_values)]
}
