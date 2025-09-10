# Local computations - Complete and Correct
locals {
  # Resource naming
  resource_name = "${var.instance_name}-postgres-${var.environment.unique_name}"
  database_name = "postgres"

  # Resource group and location from network details (matching MySQL pattern)
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

  # Networking - Create dedicated delegated subnet for PostgreSQL
  # Extract VNet name from network details
  vnet_name = var.inputs.network_details.attributes.vnet_name

  # Use VNet CIDR block to create a /28 subnet for PostgreSQL
  vnet_cidr_block = var.inputs.network_details.attributes.vnet_cidr_block

  # Naming convention for PostgreSQL subnet -
  postgres_subnet_name = "${var.instance_name}-postgres-${var.environment.unique_name}"

  # DNS zone name for PostgreSQL (required format - cannot match server name)
  postgres_dns_zone_name = "pg-dns-${var.environment.unique_name}.postgres.database.azure.com"

  # Network configuration
  network_config  = lookup(var.instance.spec, "network_config", {})
  create_dns_zone = lookup(local.network_config, "create_dns_zone", true)

  # Get DNS zone ID from either newly created or existing zone
  postgres_dns_zone_id = local.create_dns_zone ? azurerm_private_dns_zone.postgres[0].id : data.azurerm_private_dns_zone.existing[0].id

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
