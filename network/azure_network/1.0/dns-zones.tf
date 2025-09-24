#########################################################################
# Private DNS Zones for Database Services                               #
# Automatically created when respective database subnets are enabled    #
#########################################################################

# PostgreSQL Private DNS Zone
# This zone will be shared by ALL PostgreSQL Flexible Servers in this VNet
# Automatically created when PostgreSQL subnet is enabled
resource "azurerm_private_dns_zone" "postgresql" {
  count = local.create_postgresql_dns_zone ? 1 : 0

  name                = local.postgresql_dns_zone_name
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  lifecycle {
    #prevent_destroy = true # Facets best practice - protect critical resources
    ignore_changes = [tags]
  }
}

# Link PostgreSQL DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "postgresql" {
  count = local.create_postgresql_dns_zone ? 1 : 0

  name                  = "${local.name_prefix}-pg-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.postgresql[0].name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false # Don't auto-register VMs
  tags                  = local.common_tags

  lifecycle {
    ignore_changes = [tags]
  }
}

# MySQL Private DNS Zone
# This zone will be shared by ALL MySQL Flexible Servers in this VNet
# Automatically created when MySQL subnet is enabled
resource "azurerm_private_dns_zone" "mysql" {
  count = local.create_mysql_dns_zone ? 1 : 0

  name                = local.mysql_dns_zone_name
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  lifecycle {
    #prevent_destroy = true # Facets best practice - protect critical resources
    ignore_changes = [tags]
  }
}

# Link MySQL DNS Zone to VNet
resource "azurerm_private_dns_zone_virtual_network_link" "mysql" {
  count = local.create_mysql_dns_zone ? 1 : 0

  name                  = "${local.name_prefix}-mysql-dns-link"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.mysql[0].name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false # Don't auto-register VMs
  tags                  = local.common_tags

  lifecycle {
    ignore_changes = [tags]
  }
}

# Note: DNS zones are automatically created when the respective database subnet is enabled
# This ensures that the DNS infrastructure is always available when needed
