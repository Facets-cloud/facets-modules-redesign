locals {
  output_attributes = {}
  output_interfaces = {
    reader = {
      host              = length(azurerm_mysql_flexible_server.replicas) > 0 ? azurerm_mysql_flexible_server.replicas[0].fqdn : azurerm_mysql_flexible_server.main.fqdn
      port              = "3306"
      password          = local.restore_enabled ? try(var.instance.spec.restore_config.administrator_password, "") : (local.administrator_password != null ? local.administrator_password : "")
      username          = local.restore_enabled ? try(var.instance.spec.restore_config.administrator_login, "mysqladmin") : azurerm_mysql_flexible_server.main.administrator_login
      database          = local.database_name
      connection_string = (local.restore_enabled ? try(var.instance.spec.restore_config.administrator_password, null) : local.administrator_password) != null ? (length(azurerm_mysql_flexible_server.replicas) > 0 ? format("mysql://%s:%s@%s:3306/%s", local.restore_enabled ? try(var.instance.spec.restore_config.administrator_login, "mysqladmin") : azurerm_mysql_flexible_server.main.administrator_login, local.restore_enabled ? try(var.instance.spec.restore_config.administrator_password, "") : (local.administrator_password != null ? local.administrator_password : ""), azurerm_mysql_flexible_server.replicas[0].fqdn, local.database_name) : format("mysql://%s:%s@%s:3306/%s", local.restore_enabled ? try(var.instance.spec.restore_config.administrator_login, "mysqladmin") : azurerm_mysql_flexible_server.main.administrator_login, local.restore_enabled ? try(var.instance.spec.restore_config.administrator_password, "") : (local.administrator_password != null ? local.administrator_password : ""), azurerm_mysql_flexible_server.main.fqdn, local.database_name)) : ""
      secrets           = ["password", "connection_string"]
    }
    writer = {
      host              = azurerm_mysql_flexible_server.main.fqdn
      port              = "3306"
      password          = local.restore_enabled ? try(var.instance.spec.restore_config.administrator_password, "") : (local.administrator_password != null ? local.administrator_password : "")
      username          = local.restore_enabled ? try(var.instance.spec.restore_config.administrator_login, "mysqladmin") : azurerm_mysql_flexible_server.main.administrator_login
      database          = local.database_name
      connection_string = (local.restore_enabled ? try(var.instance.spec.restore_config.administrator_password, null) : local.administrator_password) != null ? format("mysql://%s:%s@%s:3306/%s", local.restore_enabled ? try(var.instance.spec.restore_config.administrator_login, "mysqladmin") : azurerm_mysql_flexible_server.main.administrator_login, local.restore_enabled ? try(var.instance.spec.restore_config.administrator_password, "") : (local.administrator_password != null ? local.administrator_password : ""), azurerm_mysql_flexible_server.main.fqdn, local.database_name) : ""
      secrets           = ["password", "connection_string"]
    }
  }
}