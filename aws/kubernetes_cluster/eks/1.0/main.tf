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
  create_kms_key                           = true
  enable_kms_key_rotation                  = true
  cluster_addons                           = local.addons
}

# Additional primary security group ingress rules (node-to-node kubelet, etc.)
locals {
  primary_sg_additional_ingress = merge({
    allow_all_vpc_traffic = {
      description = "Allow all traffic within VPC"
      port        = 0
      protocol    = "-1"
    }
  }, lookup(lookup(var.instance, "spec", {}), "primary_sg_additional_ingress", {}))
}

resource "aws_security_group_rule" "primary_sg_ingress" {
  for_each = local.primary_sg_additional_ingress

  type              = "ingress"
  security_group_id = module.eks.cluster_primary_security_group_id
  from_port         = each.value.port
  to_port           = each.value.port
  protocol          = each.value.protocol
  cidr_blocks       = [var.inputs.network_details.attributes.vpc_cidr_block]
  description       = lookup(each.value, "description", null)

  depends_on = [module.eks]

  lifecycle {
    precondition {
      condition     = try(module.eks.cluster_primary_security_group_id, "") != ""
      error_message = "Cluster primary security group id is not available yet."
    }
  }
}

