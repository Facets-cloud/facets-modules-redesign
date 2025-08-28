locals {
  output_attributes = {
    port                 = local.redis_port
    family               = local.family
    capacity             = local.capacity
    hostname             = azurerm_redis_cache.main.hostname
    location             = azurerm_redis_cache.main.location
    sku_name             = local.sku_name
    ssl_port             = local.redis_ssl_port
    subnet_id            = local.subnet_id
    cache_name           = azurerm_redis_cache.main.name
    shard_count          = local.shard_count
    redis_version        = local.redis_version
    primary_access_key   = azurerm_redis_cache.main.primary_access_key
    non_ssl_port_enabled = local.non_ssl_port_enabled
    minimum_tls_version  = local.minimum_tls_version
    replicas_per_master  = local.replicas_per_master
    resource_group_name  = local.resource_group_name
    secondary_access_key = azurerm_redis_cache.main.secondary_access_key
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