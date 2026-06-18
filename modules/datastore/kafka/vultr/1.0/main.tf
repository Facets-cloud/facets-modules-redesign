# Vultr Managed Kafka Module
# Creates a Vultr managed Kafka cluster.

module "name" {
  source        = "github.com/Facets-cloud/facets-utility-modules//name"
  environment   = var.environment
  limit         = 32
  resource_name = var.instance_name
  resource_type = "kafka"
}

locals {
  region = var.inputs.vultr_cloud_account.attributes.region
}

resource "vultr_database" "db" {
  label                   = module.name.name
  database_engine         = "kafka"
  database_engine_version = var.instance.spec.version_config.version
  region                  = local.region
  plan                    = var.instance.spec.sizing.plan
  trusted_ips             = var.instance.spec.network_access.trusted_ips

  enable_kafka_rest      = var.instance.spec.features.enable_kafka_rest
  enable_schema_registry = var.instance.spec.features.enable_schema_registry
  enable_kafka_connect   = var.instance.spec.features.enable_kafka_connect
  vpc_id                 = try(var.inputs.network.attributes.vpc_id, null)
  backup_hour            = "3"
  backup_minute          = "0"

  lifecycle {
    prevent_destroy = true
  }
}
