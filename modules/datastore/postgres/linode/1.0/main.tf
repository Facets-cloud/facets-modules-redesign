# Linode Managed PostgreSQL Module
# Creates a Linode managed PostgreSQL database (v2 API).

module "name" {
  source        = "github.com/Facets-cloud/facets-utility-modules//name"
  environment   = var.environment
  limit         = 32
  resource_name = var.instance_name
  resource_type = "postgres"
}

locals {
  region    = var.inputs.linode_cloud_account.attributes.region
  engine_id = "postgresql/${var.instance.spec.version_config.version}"
}

resource "linode_database_postgresql_v2" "db" {
  label        = module.name.name
  engine_id    = local.engine_id
  region       = local.region
  type         = var.instance.spec.sizing.type
  cluster_size = var.instance.spec.sizing.cluster_size
  allow_list   = var.instance.spec.network_access.allow_list

  lifecycle {
    prevent_destroy = true
  }
}
