locals {
  output_attributes = {
    fqdn                    = azurerm_mysql_flexible_server.main.fqdn
    version                 = azurerm_mysql_flexible_server.main.version
    location                = local.location
    sku_name                = azurerm_mysql_flexible_server.main.sku_name
    server_id               = azurerm_mysql_flexible_server.main.id
    storage_gb              = azurerm_mysql_flexible_server.main.storage != null ? azurerm_mysql_flexible_server.main.storage[0].size_gb : null
    server_name             = azurerm_mysql_flexible_server.main.name
    database_names          = local.restore_enabled ? [] : [for db in azurerm_mysql_flexible_database.databases : db.name]
    replica_servers         = length(azurerm_mysql_flexible_server.replicas) > 0 ? azurerm_mysql_flexible_server.replicas[*].fqdn : []
    administrator_login     = azurerm_mysql_flexible_server.main.administrator_login
    private_dns_zone_id     = local.mysql_dns_zone_id
    resource_group_name     = local.resource_group_name
    backup_retention_days   = azurerm_mysql_flexible_server.main.backup_retention_days
    create_mode             = azurerm_mysql_flexible_server.main.create_mode
    source_server_id        = azurerm_mysql_flexible_server.main.source_server_id
    restore_point_in_time   = azurerm_mysql_flexible_server.main.point_in_time_restore_time_in_utc
    is_restored_from_backup = local.restore_enabled
  }
  output_interfaces = {
    reader = sensitive({
      host              = length(azurerm_mysql_flexible_server.replicas) > 0 ? azurerm_mysql_flexible_server.replicas[0].fqdn : azurerm_mysql_flexible_server.main.fqdn
      port              = "\"3306\""
      password          = local.restore_enabled ? try(var.instance.spec.restore_config.administrator_password, "") : (local.administrator_password != null ? local.administrator_password : "")
      username          = local.restore_enabled ? try(var.instance.spec.restore_config.administrator_login, "mysqladmin") : azurerm_mysql_flexible_server.main.administrator_login
      connection_string = (local.restore_enabled ? try(var.instance.spec.restore_config.administrator_password, null) : local.administrator_password) != null ? (length(azurerm_mysql_flexible_server.replicas) > 0 ? format("mysql://%s:%s@%s:3306/%s", local.restore_enabled ? try(var.instance.spec.restore_config.administrator_login, "mysqladmin") : azurerm_mysql_flexible_server.main.administrator_login, local.restore_enabled ? try(var.instance.spec.restore_config.administrator_password, "") : (local.administrator_password != null ? local.administrator_password : ""), azurerm_mysql_flexible_server.replicas[0].fqdn, local.database_name) : format("mysql://%s:%s@%s:3306/%s", local.restore_enabled ? try(var.instance.spec.restore_config.administrator_login, "mysqladmin") : azurerm_mysql_flexible_server.main.administrator_login, local.restore_enabled ? try(var.instance.spec.restore_config.administrator_password, "") : (local.administrator_password != null ? local.administrator_password : ""), azurerm_mysql_flexible_server.main.fqdn, local.database_name)) : ""
    })
    writer = sensitive({
      host              = azurerm_mysql_flexible_server.main.fqdn
      port              = "\"3306\""
      password          = local.restore_enabled ? try(var.instance.spec.restore_config.administrator_password, "") : (local.administrator_password != null ? local.administrator_password : "")
      username          = local.restore_enabled ? try(var.instance.spec.restore_config.administrator_login, "mysqladmin") : azurerm_mysql_flexible_server.main.administrator_login
      connection_string = (local.restore_enabled ? try(var.instance.spec.restore_config.administrator_password, null) : local.administrator_password) != null ? format("mysql://%s:%s@%s:3306/%s", local.restore_enabled ? try(var.instance.spec.restore_config.administrator_login, "mysqladmin") : azurerm_mysql_flexible_server.main.administrator_login, local.restore_enabled ? try(var.instance.spec.restore_config.administrator_password, "") : (local.administrator_password != null ? local.administrator_password : ""), azurerm_mysql_flexible_server.main.fqdn, local.database_name) : ""
    })
    secrets = ["reader", "writer"]
  }
}