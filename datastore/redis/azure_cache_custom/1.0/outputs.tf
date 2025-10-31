locals {
  output_attributes = {}
  output_interfaces = {
    cluster = {
      port              = tostring(local.redis_ssl_port)
      endpoint          = "${azurerm_redis_cache.main.hostname}:${local.redis_ssl_port}"
      auth_token        = azurerm_redis_cache.main.primary_access_key
      connection_string = "redis://:${azurerm_redis_cache.main.primary_access_key}@${azurerm_redis_cache.main.hostname}:${local.redis_ssl_port}"
    }
    secrets = ["cluster"]
  }
}