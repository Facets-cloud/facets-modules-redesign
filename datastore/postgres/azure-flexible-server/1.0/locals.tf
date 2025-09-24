# Local computations - Simplified after network module refactoring
locals {
  # Resource naming
  # Azure PostgreSQL server names have a 63 character limit
  resource_name = "${var.instance_name}-postgres-${var.environment.unique_name}"
  database_name = "postgres"

  # For replicas, we need shorter names to stay within 63 char limit
  # Calculate how much space we have for the base name (63 - 3 for "-r#")
  max_replica_base_length = 60
  # If resource_name is too long for replicas, create a shorter version
  replica_base_name = length("${local.resource_name}-r1") <= 63 ? local.resource_name : substr(local.resource_name, 0, local.max_replica_base_length)

  # Resource group and location from network details
  resource_group_name = var.inputs.network_details.attributes.resource_group_name
  location            = var.inputs.network_details.attributes.region

  # PostgreSQL configuration
  postgres_version = var.instance.spec.version_config.version
  performance_tier = var.instance.spec.version_config.tier
  sku_name         = var.instance.spec.sizing.sku_name
  storage_gb       = var.instance.spec.sizing.storage_gb
  replica_count    = var.instance.spec.sizing.read_replica_count

  # Restore configuration
  restore_config   = lookup(var.instance.spec, "restore_config", {})
  is_restore       = lookup(local.restore_config, "restore_from_backup", false)
  source_server_id = lookup(local.restore_config, "source_server_id", null)
  restore_time     = lookup(local.restore_config, "restore_point_in_time", null)

  # Import configuration  
  imports          = lookup(var.instance.spec, "imports", {})
  import_server_id = lookup(local.imports, "flexible_server_id", null)

  # Network configuration - Consuming from network module
  vnet_name              = var.inputs.network_details.attributes.vnet_name
  vnet_id                = var.inputs.network_details.attributes.vnet_id
  postgres_subnet_id     = var.inputs.network_details.attributes.database_postgresql_subnet_id
  postgres_subnet_name   = var.inputs.network_details.attributes.database_postgresql_subnet_name
  postgres_subnet_cidr   = var.inputs.network_details.attributes.database_postgresql_subnet_cidr
  postgres_dns_zone_id   = var.inputs.network_details.attributes.postgresql_dns_zone_id
  postgres_dns_zone_name = var.inputs.network_details.attributes.postgresql_dns_zone_name

  # Security and networking defaults
  ssl_enforcement_enabled      = true
  backup_retention_days        = 7
  geo_redundant_backup_enabled = false # Disable to avoid region restrictions

  # Disable high availability to prevent Multi-Zone HA issues
  # This is a known limitation with Azure PostgreSQL Flexible Server
  # Reference: https://learn.microsoft.com/en-us/azure/postgresql/flexible-server/concepts-high-availability
  high_availability_enabled = false
  high_availability_mode    = null

  # Generate admin password
  admin_username = "psqladmin"
  admin_password = random_password.admin_password.result

  # Tags
  common_tags = merge(
    var.environment.cloud_tags,
    {
      Name        = local.resource_name
      Environment = var.environment.name
      Component   = "postgresql"
      ManagedBy   = "facets"
    }
  )
}
