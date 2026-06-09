# Vultr Managed PostgreSQL Module
# Creates a Vultr managed PostgreSQL database.

module "name" {
  source        = "github.com/Facets-cloud/facets-utility-modules//name"
  environment   = var.environment
  limit         = 32
  resource_name = var.instance_name
  resource_type = "postgres"
}

locals {
  region = var.inputs.vultr_cloud_account.attributes.region
}

resource "vultr_database" "db" {
  label                   = module.name.name
  database_engine         = "pg"
  database_engine_version = var.instance.spec.version_config.version
  region                  = local.region
  plan                    = var.instance.spec.sizing.plan
  trusted_ips             = var.instance.spec.network_access.trusted_ips

  lifecycle {
    prevent_destroy = true
  }
}
