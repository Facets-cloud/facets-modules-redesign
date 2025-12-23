locals {
  # Construct cluster name and ensure it doesn't exceed AWS limits
  # IAM role name_prefix in terraform-aws-eks appends "-cluster-" (9 chars) to cluster_name
  # Total limit is 38 chars, so cluster_name should be max 29 chars
  full_cluster_name = "${var.instance_name}-${var.environment.unique_name}"
  cluster_name      = length(local.full_cluster_name) > 29 ? substr(local.full_cluster_name, 0, 29) : local.full_cluster_name

  # Merge environment cloud tags with cluster-specific tags
  cluster_tags = merge(
    var.environment.cloud_tags,
    lookup(var.instance.spec, "cluster_tags", {}),
    {
      "facets:instance_name" = var.instance_name
      "facets:environment"   = var.environment.name
    }
  )

  # Build managed node groups configuration
  eks_managed_node_groups = {
    for ng_name, ng_config in lookup(var.instance.spec, "managed_node_groups", {}) : ng_name => {
      name = "${local.cluster_name}-${ng_name}"

      instance_types = lookup(ng_config, "instance_types", ["t3.medium"])
      capacity_type  = lookup(ng_config, "capacity_type", "ON_DEMAND")

      min_size     = lookup(ng_config, "min_size", 1)
      max_size     = lookup(ng_config, "max_size", 10)
      desired_size = lookup(ng_config, "desired_size", 2)

      disk_size = lookup(ng_config, "disk_size", 50)

      labels = lookup(ng_config, "labels", {})

      # Convert taints from map to list format expected by terraform-aws-eks
      taints = [
        for key, value in lookup(ng_config, "taints", {}) : {
          key    = key
          value  = value
          effect = "NoSchedule"
        }
      ]

      # Use the private subnets from the network input
      subnet_ids = var.inputs.network_details.attributes.private_subnet_ids

      tags = local.cluster_tags
    }
  }

  # Build cluster addons configuration
  cluster_addons_config = {
    vpc-cni = lookup(var.instance.spec.cluster_addons.vpc_cni, "enabled", true) ? {
      addon_version            = lookup(var.instance.spec.cluster_addons.vpc_cni, "version", "latest") == "latest" ? null : lookup(var.instance.spec.cluster_addons.vpc_cni, "version", null)
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = null
    } : null

    kube-proxy = lookup(var.instance.spec.cluster_addons.kube_proxy, "enabled", true) ? {
      addon_version            = lookup(var.instance.spec.cluster_addons.kube_proxy, "version", "latest") == "latest" ? null : lookup(var.instance.spec.cluster_addons.kube_proxy, "version", null)
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = null
    } : null

    coredns = lookup(var.instance.spec.cluster_addons.coredns, "enabled", true) ? {
      addon_version            = lookup(var.instance.spec.cluster_addons.coredns, "version", "latest") == "latest" ? null : lookup(var.instance.spec.cluster_addons.coredns, "version", null)
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = null
    } : null
  }

  # Filter out disabled addons
  enabled_cluster_addons = {
    for addon_name, addon_config in local.cluster_addons_config :
    addon_name => addon_config if addon_config != null
  }

  # KMS key for secrets encryption (only if enabled)
  enable_kms_key = lookup(var.instance.spec, "enable_cluster_encryption", false)
}

# KMS key for EKS secrets encryption (conditional)
resource "aws_kms_key" "eks" {
  count = local.enable_kms_key ? 1 : 0

  description             = "EKS Secret Encryption Key for ${local.cluster_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = local.cluster_tags
}

resource "aws_kms_alias" "eks" {
  count = local.enable_kms_key ? 1 : 0

  name          = "alias/eks-${local.cluster_name}"
  target_key_id = aws_kms_key.eks[0].key_id
}

# EKS Cluster using the official terraform-aws-eks module
module "eks" {
  source  = "./aws-terraform-eks"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = var.instance.spec.cluster_version

  # Network configuration
  vpc_id = var.inputs.network_details.attributes.vpc_id
  subnet_ids = concat(
    var.inputs.network_details.attributes.private_subnet_ids,
    lookup(var.inputs.network_details.attributes, "public_subnet_ids", [])
  )

  # Cluster endpoint access
  cluster_endpoint_public_access  = lookup(var.instance.spec, "cluster_endpoint_public_access", true)
  cluster_endpoint_private_access = lookup(var.instance.spec, "cluster_endpoint_private_access", true)

  # Secrets encryption configuration
  cluster_encryption_config = local.enable_kms_key ? {
    provider_key_arn = aws_kms_key.eks[0].arn
    resources        = ["secrets"]
  } : {}

  # Managed node groups
  eks_managed_node_groups = local.eks_managed_node_groups

  # Cluster addons
  cluster_addons = local.enabled_cluster_addons

  # IMPORTANT: Explicitly disable EKS Auto Mode since this is eks_standard flavor
  # EKS Auto Mode is NOT supported in this module variant
  # For Auto Mode support, use the eks_auto flavor instead
  enable_cluster_creator_admin_permissions = true

  tags = local.cluster_tags
}

# Data source to get cluster authentication token
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}
