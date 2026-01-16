locals {
  output_attributes = {}
  output_interfaces = {
    reader = {
      host              = length(azurerm_postgresql_flexible_server.replicas) > 0 ? azurerm_postgresql_flexible_server.replicas[0].fqdn : azurerm_postgresql_flexible_server.main.fqdn
      port              = 5432
      password          = local.admin_password
      username          = azurerm_postgresql_flexible_server.main.administrator_login
      connection_string = format(
        "postgres://%s:%s@%s:%d/%s",
        azurerm_postgresql_flexible_server.main.administrator_login,
        local.admin_password,
        length(azurerm_postgresql_flexible_server.replicas) > 0 ? azurerm_postgresql_flexible_server.replicas[0].fqdn : azurerm_postgresql_flexible_server.main.fqdn,
        5432,
        local.database_name
      )
      secrets           = ["password", "connection_string"]
    }
    writer = {
      host              = azurerm_postgresql_flexible_server.main.fqdn
      port              = 5432
      password          = local.admin_password
      username          = azurerm_postgresql_flexible_server.main.administrator_login
      connection_string = format(
        "postgres://%s:%s@%s:%d/%s",
        azurerm_postgresql_flexible_server.main.administrator_login,
        local.admin_password,
        azurerm_postgresql_flexible_server.main.fqdn,
        5432,
        local.database_name
      )
      secrets           = ["password", "connection_string"]
    }
  }
}