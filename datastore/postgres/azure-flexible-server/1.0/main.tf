# Create or use existing resource group
resource "azurerm_resource_group" "postgres_rg" {
  name     = local.resource_group_name
  location = local.location
  tags     = local.common_tags

  lifecycle {
    prevent_destroy = false
    ignore_changes  = [tags]
  }
}

# PostgreSQL Flexible Server - Simple and Direct
resource "azurerm_postgresql_flexible_server" "main" {
  name                = local.resource_name
  resource_group_name = azurerm_resource_group.postgres_rg.name
  location            = azurerm_resource_group.postgres_rg.location

  administrator_login    = local.admin_username
  administrator_password = local.is_restore ? null : local.admin_password

  sku_name   = local.sku_name
  version    = local.postgres_version
  storage_mb = local.storage_gb * 1024

  backup_retention_days        = local.backup_retention_days
  geo_redundant_backup_enabled = local.geo_redundant_backup_enabled

  # High availability configuration
  dynamic "high_availability" {
    for_each = local.high_availability_enabled ? [1] : []
    content {
      mode = local.high_availability_mode
    }
  }

  # Restore configuration
  source_server_id                  = local.is_restore ? local.source_server_id : null
  point_in_time_restore_time_in_utc = local.is_restore && local.restore_time != null ? local.restore_time : null
  create_mode                       = local.is_restore ? "PointInTimeRestore" : "Default"

  tags = local.common_tags

  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      zone,
      high_availability,
      administrator_password
    ]
  }
}

# Create default database
resource "azurerm_postgresql_flexible_server_database" "databases" {
  name      = local.database_name
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# PostgreSQL Flexible Server Configuration for security
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

resource "azurerm_postgresql_flexible_server_configuration" "connection_throttling" {
  name      = "connection_throttling"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

# Read replicas
resource "azurerm_postgresql_flexible_server" "replicas" {
  count = local.replica_count

  name                = "${local.resource_name}-replica-${count.index + 1}"
  resource_group_name = azurerm_resource_group.postgres_rg.name
  location            = azurerm_resource_group.postgres_rg.location

  create_mode      = "Replica"
  source_server_id = azurerm_postgresql_flexible_server.main.id

  tags = merge(local.common_tags, {
    Role = "ReadReplica"
  })

  lifecycle {
    prevent_destroy = false
  }
}