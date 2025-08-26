locals {
  # Basic configuration
  server_name         = "${var.instance_name}-mysql-${var.environment.unique_name}"
  resource_group_name = var.inputs.network_details.attributes.resource_group_name
  location            = var.inputs.network_details.attributes.region

  # MySQL configuration
  mysql_version = var.instance.spec.version_config.version
  database_name = var.instance.spec.version_config.database_name
  charset       = var.instance.spec.version_config.charset
  collation     = var.instance.spec.version_config.collation

  # Sizing configuration
  sku_name      = var.instance.spec.sizing.sku_name
  storage_gb    = var.instance.spec.sizing.storage_gb
  iops          = var.instance.spec.sizing.iops
  storage_tier  = var.instance.spec.sizing.storage_tier # Keep for reference but not used in storage block
  replica_count = var.instance.spec.sizing.read_replica_count

  # Restore configuration
  restore_enabled       = lookup(var.instance.spec.restore_config, "restore_from_backup", false)
  source_server_id      = lookup(var.instance.spec.restore_config, "source_server_id", null)
  restore_point_in_time = lookup(var.instance.spec.restore_config, "restore_point_in_time", null)

  # Credentials - use restore credentials if restoring, otherwise generate
  administrator_login    = local.restore_enabled ? lookup(var.instance.spec.restore_config, "administrator_login", "mysqladmin") : "mysqladmin"
  administrator_password = local.restore_enabled ? lookup(var.instance.spec.restore_config, "administrator_password", random_password.mysql_password.result) : random_password.mysql_password.result

  # Networking - Use existing subnet from network module
  # Try common subnet attribute names that the network module might provide
  delegated_subnet_id = lookup(var.inputs.network_details.attributes, "delegated_subnet_id",
    lookup(var.inputs.network_details.attributes, "subnet_id",
  lookup(var.inputs.network_details.attributes, "private_subnet_id", null)))

  # Security defaults (hardcoded as per requirements)
  backup_retention_days = 7

  # Tags from environment
  tags = var.environment.cloud_tags
}