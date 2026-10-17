locals {
  # Construct cluster name — use the override when importing an existing cluster,
  # otherwise auto-generate within AWS's 38-char role-name budget (submodule appends "-cluster-").
  cluster_name_override = lookup(var.instance.spec, "cluster_name_override", "")
  full_cluster_name     = "${var.instance_name}-${var.environment.unique_name}"
  auto_cluster_name     = length(local.full_cluster_name) > 29 ? substr(local.full_cluster_name, 0, 29) : local.full_cluster_name
  cluster_name          = local.cluster_name_override != "" ? local.cluster_name_override : local.auto_cluster_name

  # Merge environment cloud tags with cluster-specific tags
  cluster_tags = merge(
    var.environment.cloud_tags,
    lookup(var.instance.spec, "cluster_tags", {}),
    {
      "facets:instance_name" = var.instance_name
      "facets:environment"   = var.environment.name
    }
  )

  # Default system node pool - always created for system workloads (CoreDNS, Karpenter, etc.)
  # User can configure these values via spec.default_node_pool
  default_system_node_group = {
    system = {
      name = "sys" # Short name to avoid IAM role name length limits

      instance_types = lookup(lookup(var.instance.spec, "default_node_pool", {}), "instance_types", ["t3.medium"])
      capacity_type  = lookup(lookup(var.instance.spec, "default_node_pool", {}), "capacity_type", "ON_DEMAND")

      min_size     = lookup(lookup(var.instance.spec, "default_node_pool", {}), "size", 2)
      max_size     = lookup(lookup(var.instance.spec, "default_node_pool", {}), "size", 2)
      desired_size = lookup(lookup(var.instance.spec, "default_node_pool", {}), "size", 2)

      disk_size = lookup(lookup(var.instance.spec, "default_node_pool", {}), "disk_size", 50)

      labels = {
        "workload-type" = "system"
        "node-role"     = "system"
      }

      taints = []

      # Use the explicit node_subnet_ids override if set, else the network's private subnets.
      # node_subnet_ids is an override-only escape hatch for when the network module
      # mis-classifies subnets (e.g. IGW-routed, no NAT egress → node group CREATE_FAILED).
      subnet_ids = length(lookup(var.instance.spec, "node_subnet_ids", [])) > 0 ? lookup(var.instance.spec, "node_subnet_ids", []) : var.inputs.network_details.attributes.private_subnet_ids

      tags = merge(
        local.cluster_tags,
        {
          "Name" = "${local.cluster_name}-system-node"
        }
      )
    }
  }

  # Only the default system node group
  eks_managed_node_groups = local.default_system_node_group

  # cluster_addons is an OPTIONAL spec field (only cluster_version is required). Default to {}
  # so an omitted block doesn't crash on direct attribute access — RULE-015. The per-addon
  # `enabled`/`version` defaults below then apply, so omitting cluster_addons enables all
  # default addons (matching the schema/UI defaults).
  cluster_addons_spec = lookup(var.instance.spec, "cluster_addons", {})

  # Check if EBS CSI driver addon is enabled (default: true)
  ebs_csi_enabled = lookup(lookup(local.cluster_addons_spec, "ebs_csi", {}), "enabled", true)

  # Build cluster addons configuration - default addons
  default_addons = {
    vpc-cni = lookup(lookup(local.cluster_addons_spec, "vpc_cni", {}), "enabled", true) ? {
      addon_version            = lookup(lookup(local.cluster_addons_spec, "vpc_cni", {}), "version", "latest") == "latest" ? null : lookup(lookup(local.cluster_addons_spec, "vpc_cni", {}), "version", null)
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = null
    } : null

    kube-proxy = lookup(lookup(local.cluster_addons_spec, "kube_proxy", {}), "enabled", true) ? {
      addon_version            = lookup(lookup(local.cluster_addons_spec, "kube_proxy", {}), "version", "latest") == "latest" ? null : lookup(lookup(local.cluster_addons_spec, "kube_proxy", {}), "version", null)
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = null
    } : null

    coredns = lookup(lookup(local.cluster_addons_spec, "coredns", {}), "enabled", true) ? {
      addon_version            = lookup(lookup(local.cluster_addons_spec, "coredns", {}), "version", "latest") == "latest" ? null : lookup(lookup(local.cluster_addons_spec, "coredns", {}), "version", null)
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = null
    } : null

    aws-ebs-csi-driver = local.ebs_csi_enabled && local.create_ebs_csi_driver_role ? {
      addon_version            = lookup(lookup(local.cluster_addons_spec, "ebs_csi", {}), "version", "latest") == "latest" ? null : lookup(lookup(local.cluster_addons_spec, "ebs_csi", {}), "version", null)
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = aws_iam_role.ebs_csi_driver[0].arn
    } : null

    amazon-cloudwatch-observability = local.container_insights_enabled ? {
      addon_version            = null
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = local.needs_cloudwatch_iam_policy ? aws_iam_role.cloudwatch_agent_irsa[0].arn : null
    } : null

    metrics-server = lookup(lookup(local.cluster_addons_spec, "metrics_server", {}), "enabled", true) ? {
      addon_version            = lookup(lookup(local.cluster_addons_spec, "metrics_server", {}), "version", "latest") == "latest" ? null : lookup(lookup(local.cluster_addons_spec, "metrics_server", {}), "version", null)
      resolve_conflicts        = "OVERWRITE"
      service_account_role_arn = null
    } : null
  }

  # Build additional/custom addons configuration
  additional_addons = {
    for addon_name, addon_config in lookup(local.cluster_addons_spec, "additional_addons", {}) :
    addon_name => lookup(addon_config, "enabled", true) ? {
      addon_version            = lookup(addon_config, "version", "latest") == "latest" ? null : lookup(addon_config, "version", null)
      resolve_conflicts        = "OVERWRITE"
      configuration_values     = lookup(addon_config, "configuration_values", null)
      service_account_role_arn = lookup(addon_config, "service_account_role_arn", null)
    } : null
  }

  # Merge default and additional addons
  cluster_addons_config = merge(
    local.default_addons,
    local.additional_addons
  )

  # Filter out disabled addons
  enabled_cluster_addons = {
    for addon_name, addon_config in local.cluster_addons_config :
    addon_name => addon_config if addon_config != null
  }

  # Container Insights
  container_insights_enabled  = lookup(var.instance.spec, "container_insights_enabled", false)
  needs_cloudwatch_iam_policy = local.container_insights_enabled

  # KMS key for secrets encryption (only if enabled)
  enable_kms_key       = lookup(var.instance.spec, "customer_managed_kms", true)
  kms_key_arn_override = lookup(var.instance.spec, "kms_key_arn", "")

  # Import feature flags — reference/skip what already exists rather than creating it.
  # Defaults preserve creation behaviour; an imported cluster flips these in its env override.
  enable_eks_auto_mode       = lookup(var.instance.spec, "enable_eks_auto_mode", false)
  enable_access_entries      = lookup(var.instance.spec, "enable_access_entries", true)
  create_cluster_sg          = lookup(var.instance.spec, "create_cluster_sg", true)
  create_node_sg             = lookup(var.instance.spec, "create_node_sg", true)
  create_kms_alias           = lookup(var.instance.spec, "create_kms_alias", true)
  create_ebs_csi_driver_role = lookup(var.instance.spec, "create_ebs_csi_driver_role", true)
  create_primary_sg_tags     = lookup(var.instance.spec, "create_primary_sg_tags", true)
  create_sg_rules            = lookup(var.instance.spec, "create_sg_rules", true)

  # Existing SG ids to reference when create_*_sg=false (import: SGs built by old IaC whose
  # naming doesn't match terraform-aws-eks — reference them instead of recreating).
  cluster_security_group_id_override = lookup(var.instance.spec, "cluster_security_group_id", "")
  node_security_group_id_override    = lookup(var.instance.spec, "node_security_group_id", "")

  # Cluster IAM role: reference an existing role on import (create_cluster_iam_role=false) so the
  # live role's assume-policy/tags aren't reconciled — otherwise the module manages/creates it.
  create_cluster_iam_role = lookup(var.instance.spec, "create_cluster_iam_role", true)
  cluster_iam_role_arn    = lookup(var.instance.spec, "cluster_iam_role_arn", "")

  # Only create the control-plane log group when logging is actually enabled (live may have none).
  create_cloudwatch_log_group = length(lookup(var.instance.spec, "enabled_log_types", ["api", "audit", "authenticator", "controllerManager", "scheduler"])) > 0
}

# EKS Cluster using the official terraform-aws-eks module
module "eks" {
  source = "./aws-terraform-eks"

  cluster_name    = local.cluster_name
  cluster_version = var.instance.spec.cluster_version

  # Network configuration
  vpc_id = var.inputs.network_details.attributes.vpc_id
  # On import, pin to the live control-plane subnets so vpc_config.subnet_ids matches exactly (0-change).
  subnet_ids = length(lookup(var.instance.spec, "control_plane_subnet_ids", [])) > 0 ? var.instance.spec.control_plane_subnet_ids : concat(
    var.inputs.network_details.attributes.private_subnet_ids,
    lookup(var.inputs.network_details.attributes, "public_subnet_ids", [])
  )

  # Cluster endpoint access
  cluster_endpoint_public_access  = lookup(var.instance.spec, "cluster_endpoint_public_access", true)
  cluster_endpoint_private_access = lookup(var.instance.spec, "cluster_endpoint_private_access", true)

  # Control plane logging - all 5 log types enabled by default, user-configurable
  cluster_enabled_log_types = lookup(var.instance.spec, "enabled_log_types", ["api", "audit", "authenticator", "controllerManager", "scheduler"])

  # Secrets encryption — reference the existing KMS key on import (create_kms_alias=false),
  # else let the submodule manage its own key.
  cluster_encryption_config = jsondecode(
    local.enable_kms_key ? jsonencode(merge(
      { resources = ["secrets"] },
      local.kms_key_arn_override != "" ? { provider_key_arn = local.kms_key_arn_override } : {}
    )) : jsonencode({})
  )

  # Import flavor: node groups and addons stay UNMANAGED (live keeps running); the module owns
  # only the cluster, its SGs, role, OIDC and log group.
  eks_managed_node_groups = {}
  cluster_addons          = {}

  # SG rules — skip the module's recommended/extra rules on import (live rules stay as-is).
  node_security_group_enable_recommended_rules = local.create_sg_rules
  node_security_group_additional_rules         = {}
  cluster_security_group_additional_rules      = {}

  # Feature flags — reference existing / skip creation to match the live cluster.
  create_iam_role                            = local.create_cluster_iam_role
  iam_role_arn                               = local.cluster_iam_role_arn
  bootstrap_self_managed_addons              = false
  authentication_mode                        = lookup(var.instance.spec, "authentication_mode", "API_AND_CONFIG_MAP")
  cluster_service_ipv4_cidr                  = lookup(var.instance.spec, "service_ipv4_cidr", "") != "" ? var.instance.spec.service_ipv4_cidr : null
  create_cluster_security_group              = local.create_cluster_sg
  create_node_security_group                 = local.create_node_sg
  cluster_security_group_id                  = local.cluster_security_group_id_override
  node_security_group_id                     = local.node_security_group_id_override
  create_cluster_primary_security_group_tags = local.create_primary_sg_tags
  create_kms_key                             = local.create_kms_alias
  attach_cluster_encryption_policy           = local.create_kms_alias
  create_cloudwatch_log_group                = local.create_cloudwatch_log_group
  enable_auto_mode_custom_tags               = local.enable_eks_auto_mode
  enable_cluster_creator_admin_permissions   = local.enable_access_entries

  tags = local.cluster_tags
}

# Data source to get cluster authentication token
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

# IAM Role for EBS CSI Driver (IRSA)
resource "aws_iam_role" "ebs_csi_driver" {
  count = local.ebs_csi_enabled && local.create_ebs_csi_driver_role ? 1 : 0

  name = "${local.cluster_name}-ebs-csi-driver"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${module.eks.oidc_provider}:aud" = "sts.amazonaws.com"
            "${module.eks.oidc_provider}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          }
        }
      }
    ]
  })

  tags = local.cluster_tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  count = local.ebs_csi_enabled && local.create_ebs_csi_driver_role ? 1 : 0

  role       = aws_iam_role.ebs_csi_driver[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# CloudWatch Agent policy for node groups (when Container Insights is enabled)
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  for_each = local.needs_cloudwatch_iam_policy ? module.eks.eks_managed_node_groups : {}

  role       = each.value.iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# IAM Role for CloudWatch Agent (IRSA)
resource "aws_iam_role" "cloudwatch_agent_irsa" {
  count = local.needs_cloudwatch_iam_policy ? 1 : 0

  name = "${local.cluster_name}-cw-agent"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = module.eks.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${module.eks.oidc_provider}:aud" = "sts.amazonaws.com"
            "${module.eks.oidc_provider}:sub" = "system:serviceaccount:amazon-cloudwatch:cloudwatch-agent"
          }
        }
      }
    ]
  })

  tags = local.cluster_tags
}

# Attach CloudWatchAgentServerPolicy and any additional user-provided policies to IRSA role
resource "aws_iam_role_policy_attachment" "cloudwatch_agent_irsa" {
  for_each = local.needs_cloudwatch_iam_policy ? toset(concat(
    ["arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"],
    [for policy in values(lookup(var.instance.spec, "cloudwatch_agent_policies", {})) : policy.arn]
  )) : toset([])

  role       = aws_iam_role.cloudwatch_agent_irsa[0].name
  policy_arn = each.value
}
