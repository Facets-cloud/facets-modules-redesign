# Vultr Managed Valkey (Redis-compatible) Module
# Creates a Vultr managed Valkey database.

module "name" {
  source        = "github.com/Facets-cloud/facets-utility-modules//name"
  environment   = var.environment
  limit         = 32
  resource_name = var.instance_name
  resource_type = "redis"
}

locals {
  region = var.inputs.vultr_cloud_account.attributes.region
}

resource "vultr_database" "db" {
  label                   = module.name.name
  database_engine         = "valkey"
  database_engine_version = var.instance.spec.version_config.version
  region                  = local.region
  plan                    = var.instance.spec.sizing.plan
  eviction_policy         = var.instance.spec.advanced_config.eviction_policy
  trusted_ips             = var.instance.spec.network_access.trusted_ips
  vpc_id                  = try(var.inputs.network.attributes.vpc_id, null)
  backup_hour             = "3"
  backup_minute           = "0"

  lifecycle {
    prevent_destroy = true
  }
}
