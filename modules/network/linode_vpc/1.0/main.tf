# Linode VPC Network Module
# Creates a Linode VPC with a primary subnet for Kubernetes nodes and managed services.

locals {
  # Region falls back to the cloud account's default region when not overridden on the spec.
  region = coalesce(try(var.instance.spec.region, null), var.inputs.linode_cloud_account.attributes.region)
}

module "name" {
  source        = "github.com/Facets-cloud/facets-utility-modules//name"
  environment   = var.environment
  limit         = 64
  resource_name = var.instance_name
  resource_type = "vpc"
}

resource "linode_vpc" "main" {
  label       = module.name.name
  region      = local.region
  description = "Managed by Facets for ${var.environment.unique_name}/${var.instance_name}"
}

resource "linode_vpc_subnet" "main" {
  vpc_id = linode_vpc.main.id
  label  = module.name.name
  ipv4   = var.instance.spec.subnet_cidr
}
