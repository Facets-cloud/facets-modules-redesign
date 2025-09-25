locals {
  output_attributes = {
    port                             = local.redis_port
    family                           = local.family
    capacity                         = local.capacity
    hostname                         = azurerm_redis_cache.main.hostname
    location                         = azurerm_redis_cache.main.location
    sku_name                         = local.sku_name
    ssl_port                         = local.redis_ssl_port
    subnet_id                        = local.subnet_id
    cache_name                       = azurerm_redis_cache.main.name
    shard_count                      = local.shard_count
    subnet_type                      = local.using_database_subnet ? "database" : "private"
    redis_version                    = local.redis_version
    backup_enabled                   = local.family == "P" ? true : false
    primary_access_key               = sensitive(azurerm_redis_cache.main.primary_access_key)
    storage_name_debug               = local.storage_name_debug
    minimum_tls_version              = local.minimum_tls_version
    replicas_per_master              = local.replicas_per_master
    resource_group_name              = local.resource_group_name
    non_ssl_port_enabled             = local.non_ssl_port_enabled
    secondary_access_key             = sensitive(azurerm_redis_cache.main.secondary_access_key)
    backup_container_name            = local.create_backup_storage ? azurerm_storage_container.backup[0].name : null
    backup_storage_account_name      = local.create_backup_storage ? azurerm_storage_account.backup[0].name : null
    backup_storage_connection_string = sensitive(local.backup_storage_connection_string)
    secrets                          = ["primary_access_key", "secondary_access_key", "backup_storage_connection_string"]
  }
  output_interfaces = {
    cluster = {
      port              = tostring(local.redis_ssl_port)
      endpoint          = "${azurerm_redis_cache.main.hostname}:${local.redis_ssl_port}"
      auth_token        = azurerm_redis_cache.main.primary_access_key
      connection_string = "redis://:${azurerm_redis_cache.main.primary_access_key}@${azurerm_redis_cache.main.hostname}:${local.redis_ssl_port}"
    }
  }
}