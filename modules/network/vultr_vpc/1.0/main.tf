# Vultr VPC Network Module
# Creates a Vultr (legacy) VPC private network for Kubernetes nodes and managed services.
#
# NOTE: Vultr Kubernetes Engine (VKE) is only compatible with the original VPC
# (vultr_vpc), NOT VPC 2.0 (vultr_vpc2). vultr_vpc2 is also deprecated in the
# provider. The VPC defines its private IP range directly (no separate subnet
# resource); the cluster and the VPC must share a region.

locals {
  # Region falls back to the cloud account's default region when not overridden on the spec.
  region = coalesce(try(var.instance.spec.region, null), var.inputs.vultr_cloud_account.attributes.region)

  # Vultr VPC takes the network address and subnet mask (prefix length) separately.
  cidr_parts    = split("/", var.instance.spec.subnet_cidr)
  ip_block      = local.cidr_parts[0]
  prefix_length = tonumber(local.cidr_parts[1])
}

module "name" {
  source        = "github.com/Facets-cloud/facets-utility-modules//name"
  environment   = var.environment
  limit         = 64
  resource_name = var.instance_name
  resource_type = "vpc"
}

resource "vultr_vpc" "main" {
  region         = local.region
  description    = module.name.name
  v4_subnet      = local.ip_block
  v4_subnet_mask = local.prefix_length
}
