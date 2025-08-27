# Local computations - Simple and Direct
locals {
  # Resource naming
  resource_name = "${var.instance_name}-${var.environment.unique_name}"
  database_name = "postgres"

  # Simple resource group and location handling
  azure_config  = lookup(var.instance.spec, "azure_config", {})
  specified_rg  = lookup(local.azure_config, "resource_group_name", "")
  specified_loc = lookup(local.azure_config, "location", "")

  # Use specified values or smart defaults
  resource_group_name = local.specified_rg != "" ? local.specified_rg : "test-datastore-${var.environment.unique_name}-rg"
  location            = local.specified_loc != "" ? local.specified_loc : "East US"

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

  # Security and networking defaults
  ssl_enforcement_enabled      = true
  backup_retention_days        = 7
  geo_redundant_backup_enabled = true

  # High availability configuration based on tier
  high_availability_enabled = var.instance.spec.version_config.tier == "GeneralPurpose" || var.instance.spec.version_config.tier == "MemoryOptimized"
  high_availability_mode    = local.high_availability_enabled ? "ZoneRedundant" : null

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

# Generate random password for admin user
resource "random_password" "admin_password" {
  length  = 16
  special = true
}