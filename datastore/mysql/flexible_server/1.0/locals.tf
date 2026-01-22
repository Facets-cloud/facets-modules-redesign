locals {
  # Import flag
  import_enabled = lookup(var.instance.spec, "imports", null) != null ? lookup(var.instance.spec.imports, "import_existing", false) : false

  # Import configuration - expects full Azure resource IDs
  import_server_id   = local.import_enabled ? try(var.instance.spec.imports.server_id, null) : null
  import_database_id = local.import_enabled ? try(var.instance.spec.imports.database_id, null) : null

  # Extract server name from resource ID for use in Terraform configs
  # Format: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.DBforMySQL/flexibleServers/{name}
  import_server_name = local.import_server_id != null ? element(split("/", local.import_server_id), length(split("/", local.import_server_id)) - 1) : null

  # Mode detection
  is_import = local.import_enabled && local.import_server_id != null

  # Basic configuration
  # Azure MySQL server names have a 63 character limit
  server_name = local.is_import ? local.import_server_name : "${var.instance_name}-mysql-${var.environment.unique_name}"

  # For replicas, we need shorter names to stay within 63 char limit
  # Calculate how much space we have for the base name (63 - 3 for "-r#")
  max_replica_base_length = 60
  # If server_name is too long for replicas, create a shorter version
  replica_base_name = length("${local.server_name}-r1") <= 63 ? local.server_name : substr(local.server_name, 0, local.max_replica_base_length)

  resource_group_name = var.inputs.network_details.attributes.resource_group_name
  location            = var.inputs.network_details.attributes.region

  # MySQL configuration
  mysql_version = var.instance.spec.version_config.version
  database_name = var.instance.spec.version_config.database_name
  charset       = var.instance.spec.version_config.charset
  collation     = var.instance.spec.version_config.collation

  # Sizing configuration
  sku_name         = var.instance.spec.sizing.sku_name
  storage_gb       = var.instance.spec.sizing.storage_gb
  iops             = var.instance.spec.sizing.iops
  storage_tier     = var.instance.spec.sizing.storage_tier # Keep for reference but not used in storage block
  is_burstable_sku = startswith(local.sku_name, "B_")      # Detect if SKU is Burstable tier

  # Read replicas are not supported for Burstable SKUs - set to 0 if Burstable
  requested_replica_count = var.instance.spec.sizing.read_replica_count
  replica_count           = local.is_burstable_sku ? 0 : local.requested_replica_count

  # Restore configuration
  restore_enabled       = try(var.instance.spec.restore_config.restore_from_backup, false)
  source_server_id      = try(var.instance.spec.restore_config.source_server_id, null)
  restore_point_in_time = try(var.instance.spec.restore_config.restore_point_in_time, null)

  # Credentials - For restore operations, credentials come from source server
  # For new servers, use provided or generated credentials
  administrator_login    = local.restore_enabled ? try(var.instance.spec.restore_config.administrator_login, "mysqladmin") : "mysqladmin"
  administrator_password = local.restore_enabled ? try(var.instance.spec.restore_config.administrator_password, null) : (length(random_password.mysql_password) > 0 ? random_password.mysql_password[0].result : null)

  # Networking - Use MySQL-specific subnet and DNS zone from network module
  # The network module must have enable_mysql_flexible_subnet = true
  delegated_subnet_id = var.inputs.network_details.attributes.database_mysql_subnet_id
  mysql_dns_zone_id   = var.inputs.network_details.attributes.mysql_dns_zone_id
  vnet_id             = var.inputs.network_details.attributes.vnet_id

  # Security defaults (hardcoded as per requirements)
  backup_retention_days = 7

  # Tags from environment
  tags = var.environment.cloud_tags
}