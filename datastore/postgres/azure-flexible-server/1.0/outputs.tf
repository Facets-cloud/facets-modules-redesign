locals {
  output_attributes = {
    fqdn                         = azurerm_postgresql_flexible_server.main.fqdn
    version                      = azurerm_postgresql_flexible_server.main.version
    location                     = azurerm_postgresql_flexible_server.main.location
    sku_name                     = azurerm_postgresql_flexible_server.main.sku_name
    server_id                    = azurerm_postgresql_flexible_server.main.id
    storage_gb                   = azurerm_postgresql_flexible_server.main.storage_mb / 1024
    server_name                  = azurerm_postgresql_flexible_server.main.name
    database_names               = [local.database_name]
    replica_servers              = azurerm_postgresql_flexible_server.replicas[*].fqdn
    administrator_login          = azurerm_postgresql_flexible_server.main.administrator_login
    delegated_subnet_id          = local.postgres_subnet_id
    delegated_subnet_name        = local.postgres_subnet_name
    delegated_subnet_cidr        = local.postgres_subnet_cidr
    private_dns_zone_id          = local.postgres_dns_zone_id
    private_dns_zone_name        = local.postgres_dns_zone_name
    resource_group_name          = local.resource_group_name
    backup_retention_days        = azurerm_postgresql_flexible_server.main.backup_retention_days
    high_availability_enabled    = local.high_availability_enabled
    geo_redundant_backup_enabled = azurerm_postgresql_flexible_server.main.geo_redundant_backup_enabled
  }
  output_interfaces = {
    reader = sensitive({
      host              = length(azurerm_postgresql_flexible_server.replicas) > 0 ? azurerm_postgresql_flexible_server.replicas[0].fqdn : azurerm_postgresql_flexible_server.main.fqdn
      password          = local.is_restore ? "RESTORED_SERVER_USE_ORIGINAL_PASSWORD" : local.admin_password
      username          = azurerm_postgresql_flexible_server.main.administrator_login
      connection_string = local.is_restore ? format("postgres://%s:RESTORED_SERVER_USE_ORIGINAL_PASSWORD@%s:%d/%s", azurerm_postgresql_flexible_server.main.administrator_login, length(azurerm_postgresql_flexible_server.replicas) > 0 ? azurerm_postgresql_flexible_server.replicas[0].fqdn : azurerm_postgresql_flexible_server.main.fqdn, 5432, local.database_name) : (length(azurerm_postgresql_flexible_server.replicas) > 0 ? format("postgres://%s:%s@%s:%d/%s", azurerm_postgresql_flexible_server.main.administrator_login, local.admin_password, azurerm_postgresql_flexible_server.replicas[0].fqdn, 5432, local.database_name) : format("postgres://%s:%s@%s:%d/%s", azurerm_postgresql_flexible_server.main.administrator_login, local.admin_password, azurerm_postgresql_flexible_server.main.fqdn, 5432, local.database_name))
    })
    writer = sensitive({
      host              = azurerm_postgresql_flexible_server.main.fqdn
      password          = local.is_restore ? "RESTORED_SERVER_USE_ORIGINAL_PASSWORD" : local.admin_password
      username          = azurerm_postgresql_flexible_server.main.administrator_login
      connection_string = local.is_restore ? format("postgres://%s:RESTORED_SERVER_USE_ORIGINAL_PASSWORD@%s:%d/%s", azurerm_postgresql_flexible_server.main.administrator_login, azurerm_postgresql_flexible_server.main.fqdn, 5432, local.database_name) : format("postgres://%s:%s@%s:%d/%s", azurerm_postgresql_flexible_server.main.administrator_login, local.admin_password, azurerm_postgresql_flexible_server.main.fqdn, 5432, local.database_name)
    })
    secrets = ["reader", "writer"]
  }
}