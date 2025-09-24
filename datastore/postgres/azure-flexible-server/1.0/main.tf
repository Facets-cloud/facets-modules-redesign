# Generate random password for PostgreSQL admin
resource "random_password" "admin_password" {
  length  = 16
  special = true
}

# PostgreSQL Flexible Server - Using network module resources
resource "azurerm_postgresql_flexible_server" "main" {
  name                = local.resource_name
  resource_group_name = local.resource_group_name
  location            = local.location

  administrator_login    = local.is_restore ? null : local.admin_username
  administrator_password = local.is_restore ? null : local.admin_password

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
      zone,
      administrator_password,
      # Ignore changes that would require recreation
      delegated_subnet_id,
      private_dns_zone_id,
      # Ignore restore-related attributes that change after restore
      create_mode,
      source_server_id,
      point_in_time_restore_time_in_utc
    ]
  }
}

# Create default database - conditional creation to handle existing "postgres" database
# Skip database creation during restore as Azure automatically restores all databases
resource "azurerm_postgresql_flexible_server_database" "databases" {
  count     = local.is_restore ? 0 : (local.database_name == "postgres" ? 0 : 1)
  name      = local.database_name
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# PostgreSQL Flexible Server Configuration for security - version-compatible settings only
resource "azurerm_postgresql_flexible_server_configuration" "log_connections" {
  name      = "log_connections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

resource "azurerm_postgresql_flexible_server_configuration" "log_disconnections" {
  name      = "log_disconnections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
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
