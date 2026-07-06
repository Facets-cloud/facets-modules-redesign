# Vultr Managed MySQL Module
# Creates a Vultr managed MySQL database.

module "name" {
  source        = "github.com/Facets-cloud/facets-utility-modules//name"
  environment   = var.environment
  limit         = 32
  resource_name = var.instance_name
  resource_type = "mysql"
}

locals {
  region = var.inputs.vultr_cloud_account.attributes.region
}

resource "vultr_database" "db" {
  label                   = module.name.name
  database_engine         = "mysql"
  database_engine_version = var.instance.spec.version_config.version
  region                  = local.region
  plan                    = var.instance.spec.sizing.plan
  trusted_ips             = var.instance.spec.network_access.trusted_ips

  mysql_slow_query_log      = var.instance.spec.advanced_config.slow_query_log
  mysql_long_query_time     = var.instance.spec.advanced_config.slow_query_log ? var.instance.spec.advanced_config.long_query_time : null
  mysql_require_primary_key = var.instance.spec.advanced_config.require_primary_key
  vpc_id                    = try(var.inputs.network.attributes.vpc_id, null)
  backup_hour               = "3"
  backup_minute             = "0"

  lifecycle {
    prevent_destroy = true
  }
}
