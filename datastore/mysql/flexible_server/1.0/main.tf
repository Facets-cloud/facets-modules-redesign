# Generate random password for MySQL admin
resource "random_password" "mysql_password" {
  length  = 16
  special = true
}

# Private DNS Zone for MySQL (MUST end with .mysql.database.azure.com)
resource "azurerm_private_dns_zone" "mysql" {
  name                = "${local.server_name}.mysql.database.azure.com"
  resource_group_name = local.resource_group_name
  tags                = local.tags
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  name                  = "${local.server_name}-dns-link"
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.mysql.name
  virtual_network_id    = var.inputs.network_details.attributes.vnet_id
  tags                  = local.tags
}

# MySQL Flexible Server
resource "azurerm_mysql_flexible_server" "main" {
  name                = local.server_name
  resource_group_name = local.resource_group_name
  location            = local.location

  # Server configuration
  administrator_login    = local.administrator_login
  administrator_password = local.administrator_password

  # Version and SKU
  version  = local.mysql_version
  sku_name = local.sku_name

  # Storage configuration
  storage {
    size_gb = local.storage_gb
    iops    = local.iops
  }

  # Security and backup
  backup_retention_days        = local.backup_retention_days
  geo_redundant_backup_enabled = true

  # High availability (conditional based on SKU tier - not supported for Burstable)
  dynamic "high_availability" {
    for_each = local.is_burstable_sku ? [] : [1]
    content {
      mode = "ZoneRedundant"
    }
  }

  # Network configuration - Use existing subnet from network module
  delegated_subnet_id = local.delegated_subnet_id
  private_dns_zone_id = azurerm_private_dns_zone.mysql.id

  # Restore configuration (conditional) - Fixed syntax
  source_server_id                  = local.restore_enabled && local.source_server_id != null ? local.source_server_id : null
  point_in_time_restore_time_in_utc = local.restore_enabled && local.restore_point_in_time != null ? local.restore_point_in_time : null

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = false # Set to false for testing as requested
    ignore_changes = [
      # Ignore changes that would require recreation
      delegated_subnet_id,
      private_dns_zone_id
    ]
  }

  tags = local.tags

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.mysql
  ]
}

# MySQL Database
resource "azurerm_mysql_flexible_database" "databases" {
  count               = 1
  name                = local.database_name
  resource_group_name = local.resource_group_name
  server_name         = azurerm_mysql_flexible_server.main.name
  charset             = local.charset
  collation           = local.collation
}

# Read Replicas (if configured) - Updated configuration
resource "azurerm_mysql_flexible_server" "replicas" {
  count = local.replica_count

  name                = "${local.server_name}-replica-${count.index + 1}"
  resource_group_name = local.resource_group_name
  location            = local.location

  # Replica configuration - Fixed syntax
  source_server_id = azurerm_mysql_flexible_server.main.id

  # Same version as primary
  version  = local.mysql_version
  sku_name = local.sku_name

  # Storage (must match primary) - Simplified
  storage {
    size_gb = local.storage_gb
  }

  # Network - Use existing subnet from network module
  delegated_subnet_id = local.delegated_subnet_id
  private_dns_zone_id = azurerm_private_dns_zone.mysql.id

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = false # Set to false for testing
  }

  tags = local.tags

  depends_on = [
    azurerm_mysql_flexible_server.main
  ]
}

# Firewall rule to allow Azure services (optional for private access)
resource "azurerm_mysql_flexible_server_firewall_rule" "azure_services" {
  name                = "${local.server_name}-azure-services"
  resource_group_name = local.resource_group_name
  server_name         = azurerm_mysql_flexible_server.main.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}