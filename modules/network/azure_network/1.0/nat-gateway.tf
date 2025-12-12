#########################################################################
# NAT Gateway Resources                                                  #
#########################################################################

# Public IP for NAT Gateway
resource "azurerm_public_ip" "nat_gateway" {
  for_each = var.instance.spec.nat_gateway.strategy == "per_az" ? {
    for az in var.instance.spec.availability_zones : az => az
    } : {
    single = var.instance.spec.availability_zones[0]
  }

  name                = var.instance.spec.nat_gateway.strategy == "per_az" ? "${local.name_prefix}-natgw-pip-${each.key}" : "${local.name_prefix}-natgw-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [each.value]

  tags = local.common_tags

  lifecycle {
    ignore_changes = [name]
  }
}

# NAT Gateway
resource "azurerm_nat_gateway" "main" {
  for_each = var.instance.spec.nat_gateway.strategy == "per_az" ? {
    for az in var.instance.spec.availability_zones : az => az
    } : {
    single = var.instance.spec.availability_zones[0]
  }

  name                    = var.instance.spec.nat_gateway.strategy == "per_az" ? "${local.name_prefix}-natgw-${each.key}" : "${local.name_prefix}-natgw"
  location                = azurerm_resource_group.main.location
  resource_group_name     = azurerm_resource_group.main.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
  zones                   = [each.value]

  tags = local.common_tags

  lifecycle {
    ignore_changes = [name]
  }
}

# Associate Public IP with NAT Gateway
resource "azurerm_nat_gateway_public_ip_association" "main" {
  for_each = azurerm_nat_gateway.main

  nat_gateway_id       = each.value.id
  public_ip_address_id = azurerm_public_ip.nat_gateway[each.key].id
}

# Associate NAT Gateway with Private Subnets
resource "azurerm_subnet_nat_gateway_association" "private" {
  for_each = azurerm_subnet.private

  subnet_id      = each.value.id
  nat_gateway_id = var.instance.spec.nat_gateway.strategy == "per_az" ? azurerm_nat_gateway.main[each.value.az].id : azurerm_nat_gateway.main["single"].id
}
