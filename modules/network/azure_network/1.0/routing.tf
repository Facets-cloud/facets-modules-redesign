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

#########################################################################
# Database Subnet Routing                                               #
#########################################################################

# Note: Delegated subnets for PostgreSQL and MySQL handle their own routing
# The general database subnet needs routing for resources to reach internet via NAT Gateway

# Associate general database subnet with private route table for NAT Gateway routing
# For per_az strategy, we need to handle multiple AZs properly
resource "azurerm_subnet_route_table_association" "database_general" {
  count = local.enable_general_database_subnet ? 1 : 0

  subnet_id = azurerm_subnet.database_subnets[0].id

  # For per_az strategy, use the first AZ's route table as default
  # All AZs share the same database subnets, so we use the first AZ's route table
  route_table_id = var.instance.spec.nat_gateway.strategy == "per_az" ? (
    length(var.instance.spec.availability_zones) > 0 ?
    azurerm_route_table.private[var.instance.spec.availability_zones[0]].id :
    azurerm_route_table.private["single"].id
  ) : azurerm_route_table.private["single"].id
}

# Note: For database subnets that span all AZs, routing through the first AZ's NAT Gateway
# is acceptable as database traffic is typically internal to the VNet.
# If zone-specific routing is required, consider creating per-AZ database subnets.
