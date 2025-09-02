#########################################################################
# Route Tables and Routing                                              #
#########################################################################

# Route Table for Public Subnets
resource "azurerm_route_table" "public" {
  name                = "${local.name_prefix}-public-rt"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

# Associate Route Table with Public Subnets
resource "azurerm_subnet_route_table_association" "public" {
  for_each = azurerm_subnet.public

  subnet_id      = each.value.id
  route_table_id = azurerm_route_table.public.id
}

# Route Table for Private Subnets
resource "azurerm_route_table" "private" {
  for_each = var.instance.spec.nat_gateway.strategy == "per_az" ? {
    for az in var.instance.spec.availability_zones : az => az
    } : {
    single = "1"
  }

  name                = var.instance.spec.nat_gateway.strategy == "per_az" ? "${local.name_prefix}-private-rt-${each.key}" : "${local.name_prefix}-private-rt"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = local.common_tags
}

# Associate Route Table with Private Subnets
resource "azurerm_subnet_route_table_association" "private" {
  for_each = azurerm_subnet.private

  subnet_id      = each.value.id
  route_table_id = var.instance.spec.nat_gateway.strategy == "per_az" ? azurerm_route_table.private[each.value.az].id : azurerm_route_table.private["single"].id
}
