locals {
  name                                   = module.name.name
  spec                                   = lookup(var.instance, "spec", {})
  cluster                                = lookup(local.spec, "cluster", {})
  cluster_location                       = var.inputs.cloud_account.attributes.aws_region
  cluster_endpoint_public_access         = lookup(local.cluster, "cluster_endpoint_public_access", true)
  cluster_endpoint_private_access        = true
  cluster_endpoint_public_access_cidrs   = length(lookup(local.cluster, "cluster_endpoint_public_access_cidrs", [])) > 0 ? lookup(local.cluster, "cluster_endpoint_public_access_cidrs", ["0.0.0.0/0"]) : ["0.0.0.0/0"]
  kubernetes_version                     = null # Use latest available version by default
  cloudwatch_config                      = lookup(local.cluster, "cloudwatch", {})
  cluster_enabled_log_types              = lookup(local.cloudwatch_config, "enabled_log_types", ["api", "audit", "authenticator", "controllerManager", "scheduler"])
  cloudwatch_log_group_retention_in_days = lookup(local.cloudwatch_config, "log_group_retention_in_days", 90)
  cluster_endpoint_private_access_cidrs  = lookup(local.cluster, "cluster_endpoint_private_access_cidrs", [])
  cluster_service_ipv4_cidr              = lookup(local.cluster, "cluster_service_ipv4_cidr", null)
  container_insights_enabled             = lookup(local.cloudwatch_config, "container_insights_enabled", false)
  cluster_addons                         = lookup(local.cluster, "cluster_addons", {})
  cloud_tags                             = var.environment.cloud_tags
  default_addons = local.container_insights_enabled ? {
    amazon-cloudwatch-observability = {
      name                        = "amazon-cloudwatch-observability"
      addon_version               = null
      configuration_values        = null
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
      tags                        = local.cloud_tags
      preserve                    = false
      service_account_role_arn    = null
    }
  } : {}
  user_addons = {
    for name, attributes in local.cluster_addons : name => {
      name          = lookup(attributes, "name", null)
      addon_version = lookup(attributes, "addon_version", null)
      configuration_values = (
        lookup(attributes, "configuration_values", null) != null ?
        jsonencode(lookup(attributes, "configuration_values", null)) :
        null
      )
      resolve_conflicts_on_create = "OVERWRITE"
      resolve_conflicts_on_update = "OVERWRITE"
      tags                        = local.cloud_tags
      preserve                    = false
      service_account_role_arn    = lookup(attributes, "service_account_role_arn", null)
    }
    if lookup(attributes, "enabled", true)
  }
  addons = merge(local.default_addons, local.user_addons)
  cluster_compute_config = {
    enabled    = true
    node_pools = ["system", "general-purpose"]
  }
  cluster_security_group_additional_rules = { for idx, cidr in local.cluster_endpoint_private_access_cidrs :
    "ingress_private_cidr_${idx}" => {
      description = "Allow private CIDR ${cidr} access to cluster API"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      type        = "ingress"
      cidr_blocks = [cidr]
    }
  }
  node_security_group_additional_rules = {
    allow_all_vpc_traffic = {
      description = "Allow all traffic within VPC"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      type        = "ingress"
      cidr_blocks = [var.inputs.network_details.attributes.vpc_cidr_block]
    }
  }
  cluster_primary_security_group_additional_rules = {
    allow_all_vpc_traffic = {
      description = "Allow all traffic within VPC"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      type        = "ingress"
      cidr_blocks = [var.inputs.network_details.attributes.vpc_cidr_block]
    }
  }
  tags = merge(var.environment.cloud_tags, lookup(local.spec, "tags", {}))
}