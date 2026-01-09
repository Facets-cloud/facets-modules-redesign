# Generate random password for PostgreSQL admin (skip during restore or import)
resource "random_password" "admin_password" {
  count   = local.is_restore ? 0 : 1
  length  = 16
  special = true

  lifecycle {
    ignore_changes = [
      length,
      special,
    ]
  }
}

# PostgreSQL Flexible Server - Using network module resources
resource "azurerm_postgresql_flexible_server" "main" {
  name                = local.resource_name
  resource_group_name = local.resource_group_name
  location            = local.location

  administrator_login    = local.admin_username
  administrator_password = local.admin_password

  sku_name   = local.sku_name
  version    = local.postgres_version
  storage_mb = local.storage_gb * 1024

  backup_retention_days        = local.backup_retention_days
  geo_redundant_backup_enabled = local.geo_redundant_backup_enabled

  # Network configuration - Using subnet and DNS zone from network module
  delegated_subnet_id = local.postgres_subnet_id
  private_dns_zone_id = local.postgres_dns_zone_id

  # CRITICAL: Disable public network access when using VNet integration
  public_network_access_enabled = false

  # Restore configuration
  source_server_id                  = local.is_restore ? local.source_server_id : null
  point_in_time_restore_time_in_utc = local.is_restore && local.restore_time != null ? local.restore_time : null
  create_mode                       = local.is_restore ? "PointInTimeRestore" : "Default"

  tags = local.common_tags

  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      # Ignore changes that would cause resource replacement during import
      name,
      location,
      resource_group_name,
      administrator_login,
      administrator_password,
      sku_name,
      version,
      storage_mb,
      backup_retention_days,
      geo_redundant_backup_enabled,
      delegated_subnet_id,
      private_dns_zone_id,
      public_network_access_enabled,
      create_mode,
      source_server_id,
      point_in_time_restore_time_in_utc,
      zone,
      tags
    ]
  }
}

# Database resource - Conditional creation/import logic
# CRITICAL: The "postgres" database is a system database that:
#   - Always exists on the server (created automatically by Azure)
#   - Cannot be explicitly deleted via API (Azure blocks this)
#   - Is automatically removed when the server is deleted
#
# Count logic:
#   - Restore mode: count = 0 (all databases auto-restored by Azure)
#   - Database name is "postgres": count = 0 (cannot manage system database)
#   - Custom database name + Create mode: count = 1 (create new database)
#   - Custom database name + Import mode: count = 1 (import existing database)
resource "azurerm_postgresql_flexible_server_database" "databases" {
  count     = local.is_restore || local.database_name == "postgres" ? 0 : 1
  name      = local.database_name
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"

  lifecycle {
    ignore_changes = [
      name,
      server_id,
      collation,
      charset
    ]
  }
}

# PostgreSQL Flexible Server Configuration for security - version-compatible settings only
# Skip during import as configurations already exist on the imported server
resource "azurerm_postgresql_flexible_server_configuration" "log_connections" {
  count = local.is_import ? 0 : 1

  name      = "log_connections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"

  lifecycle {
    ignore_changes = [name, server_id, value]
  }
}

resource "azurerm_postgresql_flexible_server_configuration" "log_disconnections" {
  count = local.is_import ? 0 : 1

  name      = "log_disconnections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"

  lifecycle {
    ignore_changes = [name, server_id, value]
  }
}

# Note: connection_throttling is not supported in PostgreSQL 15+ on Azure Flexible Server

# Read replicas - only create if count > 0
resource "azurerm_postgresql_flexible_server" "replicas" {
  count = local.replica_count

  # Use shorter name pattern for replicas to stay within 63 character limit
  name                = "${local.replica_base_name}-r${count.index + 1}"
  resource_group_name = local.resource_group_name
  location            = local.location

  create_mode      = "Replica"
  source_server_id = azurerm_postgresql_flexible_server.main.id

  # Replicas must have same or larger storage and SKU as primary
  sku_name   = local.sku_name
  version    = local.postgres_version
  storage_mb = local.storage_gb * 1024

  # Network configuration - Using same subnet and DNS zone from network module
  delegated_subnet_id = local.postgres_subnet_id
  private_dns_zone_id = local.postgres_dns_zone_id

  # CRITICAL: Disable public network access when using VNet integration (consistent with primary)
  public_network_access_enabled = false

  tags = merge(local.common_tags, {
    Role = "ReadReplica"
  })

  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      # Ignore changes that would require recreation
      delegated_subnet_id,
      private_dns_zone_id,
      storage_mb # Ignore storage changes after creation
    ]
  }

  depends_on = [
    azurerm_postgresql_flexible_server.main
  ]
}
