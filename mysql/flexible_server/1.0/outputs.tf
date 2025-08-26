locals {
  output_attributes = {
    server_id             = azurerm_mysql_flexible_server.main.id
    server_name           = azurerm_mysql_flexible_server.main.name
    fqdn                  = azurerm_mysql_flexible_server.main.fqdn
    administrator_login   = azurerm_mysql_flexible_server.main.administrator_login
    version               = azurerm_mysql_flexible_server.main.version
    sku_name              = azurerm_mysql_flexible_server.main.sku_name
    storage_gb            = azurerm_mysql_flexible_server.main.storage[0].size_gb
    backup_retention_days = azurerm_mysql_flexible_server.main.backup_retention_days
    resource_group_name   = local.resource_group_name
    location              = local.location
    database_names        = [for db in azurerm_mysql_flexible_database.databases : db.name]
    replica_servers       = length(azurerm_mysql_flexible_server.replicas) > 0 ? azurerm_mysql_flexible_server.replicas[*].fqdn : []
    private_dns_zone_id   = azurerm_private_dns_zone.mysql.id
  }
  output_interfaces = {
    writer = {
      host              = azurerm_mysql_flexible_server.main.fqdn
      username          = azurerm_mysql_flexible_server.main.administrator_login
      password          = local.administrator_password
      connection_string = "mysql://${azurerm_mysql_flexible_server.main.administrator_login}:${local.administrator_password}@${azurerm_mysql_flexible_server.main.fqdn}:3306/${local.database_name}"
    }
    reader = {
      host              = length(azurerm_mysql_flexible_server.replicas) > 0 ? azurerm_mysql_flexible_server.replicas[0].fqdn : azurerm_mysql_flexible_server.main.fqdn
      username          = azurerm_mysql_flexible_server.main.administrator_login
      password          = local.administrator_password
      connection_string = length(azurerm_mysql_flexible_server.replicas) > 0 ? "mysql://${azurerm_mysql_flexible_server.main.administrator_login}:${local.administrator_password}@${azurerm_mysql_flexible_server.replicas[0].fqdn}:3306/${local.database_name}" : "mysql://${azurerm_mysql_flexible_server.main.administrator_login}:${local.administrator_password}@${azurerm_mysql_flexible_server.main.fqdn}:3306/${local.database_name}"
    }
  }
}