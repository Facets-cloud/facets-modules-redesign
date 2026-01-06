locals {
  # Private Endpoint IP for connections
  private_ip = azurerm_private_endpoint.redis.private_service_connection[0].private_ip_address

  # Hostname that resolves via Private DNS to the private IP
  # Clients in the VNet can use this hostname directly
  private_hostname = "${local.cache_name}.privatelink.redisenterprise.cache.azure.net"

  output_attributes = {
    # Cache details
    cache_name = azurerm_managed_redis.main.name
    cache_id   = azurerm_managed_redis.main.id

    # Private Endpoint details
    private_endpoint_ip   = local.private_ip
    private_endpoint_id   = azurerm_private_endpoint.redis.id
    private_endpoint_name = azurerm_private_endpoint.redis.name

    # Private DNS details
    private_dns_zone_id   = azurerm_private_dns_zone.redis.id
    private_dns_zone_name = azurerm_private_dns_zone.redis.name
    private_hostname      = local.private_hostname

    # Original public hostname (for reference, not accessible)
    public_hostname = azurerm_managed_redis.main.hostname
  }

  output_interfaces = {
    cluster = {
      host              = local.private_hostname
      port              = tostring(local.redis_port)
      endpoint          = "${local.private_hostname}:${local.redis_port}"
      auth_token        = azurerm_managed_redis.main.default_database[0].primary_access_key
      connection_string = "rediss://:${azurerm_managed_redis.main.default_database[0].primary_access_key}@${local.private_hostname}:${local.redis_port}"
      secrets           = ["auth_token", "connection_string"]
    }
  }
}
