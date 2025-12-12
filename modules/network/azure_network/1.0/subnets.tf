#########################################################################
# Subnet Resources                                                      #
#########################################################################

# Public Subnets - 1 per AZ with /24 (256 IPs each)
resource "azurerm_subnet" "public" {
  for_each = {
    for subnet in local.public_subnets :
    "${subnet.az}" => subnet
  }

  name                 = "${local.name_prefix}-public-${each.value.az}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [each.value.cidr_block]
  service_endpoints    = ["Microsoft.Storage"]

  lifecycle {
    ignore_changes = [delegation, service_endpoints, name]
  }
}

# Private Subnets - 1 per AZ with /18 (16,384 IPs each)
resource "azurerm_subnet" "private" {
  for_each = {
    for subnet in local.private_subnets :
    "${subnet.az}" => subnet
  }

  name                 = "${local.name_prefix}-private-${each.value.az}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [each.value.cidr_block]
  service_endpoints    = ["Microsoft.Storage"]

  lifecycle {
    ignore_changes = [service_endpoints, name]
  }
}
