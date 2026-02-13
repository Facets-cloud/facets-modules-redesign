module "name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 32
  resource_name   = var.instance_name
  resource_type   = "kubernetes_cluster"
  globally_unique = true
}

module "eks" {
  source                                   = "./aws-terraform-eks"
  cluster_name                             = module.name.name
  cluster_compute_config                   = local.cluster_compute_config
  cluster_version                          = local.kubernetes_version
  cluster_endpoint_public_access           = local.cluster_endpoint_public_access
  cluster_endpoint_private_access          = local.cluster_endpoint_private_access
  cluster_endpoint_public_access_cidrs     = local.cluster_endpoint_public_access_cidrs
  enable_cluster_creator_admin_permissions = true
  cluster_enabled_log_types                = local.cluster_enabled_log_types
  vpc_id                                   = var.inputs.network_details.attributes.vpc_id
  subnet_ids                               = var.inputs.network_details.attributes.private_subnet_ids
  cluster_security_group_additional_rules  = local.cluster_security_group_additional_rules
  cloudwatch_log_group_retention_in_days   = local.cloudwatch_log_group_retention_in_days
  cluster_service_ipv4_cidr                = local.cluster_service_ipv4_cidr
  tags                                     = local.tags
  create_kms_key                           = lookup(var.instance.spec.cluster, "enable_cluster_encryption", true)
  enable_kms_key_rotation                  = lookup(var.instance.spec.cluster, "enable_cluster_encryption", true)
  cluster_addons                           = local.addons
  node_security_group_additional_rules     = local.node_security_group_additional_rules
  node_iam_role_additional_policies        = local.container_insights_enabled ? { CloudWatchAgentServerPolicy = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy" } : {}
}

resource "aws_security_group_rule" "cluster_primary_sg_ingress" {
  for_each = local.cluster_primary_security_group_additional_rules

  type              = each.value.type
  security_group_id = module.eks.cluster_primary_security_group_id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = each.value.cidr_blocks
  description       = lookup(each.value, "description", null)

  lifecycle {
    precondition {
      condition     = try(module.eks.cluster_primary_security_group_id, "") != ""
      error_message = "Cluster primary security group id is not available yet."
    }
  }
}
