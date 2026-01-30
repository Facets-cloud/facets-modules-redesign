# Azure Managed Redis (Redis Enterprise)
resource "azurerm_managed_redis" "main" {
  name                = local.cache_name
  location            = local.region
  resource_group_name = local.resource_group_name
  sku_name            = local.sku_name

  # VNet-only access - disable public network access
  public_network_access = "Disabled"

  tags = local.tags

  # Database configuration
  default_database {
    client_protocol                    = local.client_protocol
    clustering_policy                  = local.clustering_policy
    eviction_policy                    = local.eviction_policy
    access_keys_authentication_enabled = local.access_keys_authentication_enabled
  }

  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      # Immutable attributes that cannot be changed after creation
      name,
      location,
      sku_name,
    ]
  }
}

# Private Endpoint for secure VNet access
resource "azurerm_private_endpoint" "redis" {
  name                = "${local.cache_name}-pe"
  location            = local.region
  resource_group_name = local.resource_group_name
  subnet_id           = local.subnet_id

  private_service_connection {
    name                           = "${local.cache_name}-psc"
    private_connection_resource_id = azurerm_managed_redis.main.id
    is_manual_connection           = false
    subresource_names              = ["redisCache"]
  }

  tags = local.tags
}

# Private DNS Zone for Private Endpoint resolution
resource "azurerm_private_dns_zone" "redis" {
  name                = "privatelink.redisenterprise.cache.azure.net"
  resource_group_name = local.resource_group_name

  tags = local.tags
}

# Link Private DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "redis" {
  name                  = "${local.cache_name}-dns-link"
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.redis.name
  virtual_network_id    = local.vnet_id

  tags = local.tags
}

# DNS A record for Private Endpoint
resource "azurerm_private_dns_a_record" "redis" {
  name                = local.cache_name
  zone_name           = azurerm_private_dns_zone.redis.name
  resource_group_name = local.resource_group_name
  ttl                 = 300
  records             = [azurerm_private_endpoint.redis.private_service_connection[0].private_ip_address]
}
