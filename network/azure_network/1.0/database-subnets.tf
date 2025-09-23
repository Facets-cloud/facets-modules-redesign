#########################################################################
# Database Subnet Resources                                             #
# Includes general database subnet and delegated subnets               #
#########################################################################

# General Database Subnet - No delegation, for resources that use private endpoints
resource "azurerm_subnet" "database_subnets" {
  count = local.enable_general_database_subnet ? 1 : 0

  name                 = "${local.name_prefix}-db-general"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.database_subnet_cidrs.general]

  # Service endpoints for general database access
  service_endpoints = [
    "Microsoft.Storage",
    "Microsoft.Sql",
    "Microsoft.AzureCosmosDB",
    "Microsoft.KeyVault",
    "Microsoft.ServiceBus"
  ]

  lifecycle {
    ignore_changes = [name]
  }
}

# PostgreSQL Flexible Server Delegated Subnet - ONLY for PostgreSQL Flexible Servers
resource "azurerm_subnet" "database_flexibleserver_postgresql" {
  count = local.enable_postgresql_flexible_subnet ? 1 : 0

  name                 = "${local.name_prefix}-db-postgresql"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.database_subnet_cidrs.postgresql]

  # CRITICAL: Delegate subnet to PostgreSQL Flexible Servers
  # This means ONLY PostgreSQL Flexible Servers can use this subnet
  delegation {
    name = "postgresql-flexible-delegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }

  # Service endpoints required for PostgreSQL operations
  service_endpoints = ["Microsoft.Storage"]

  lifecycle {
    ignore_changes = [name]
    # Don't ignore delegation changes as they're critical for functionality
  }
}

# MySQL Flexible Server Delegated Subnet - ONLY for MySQL Flexible Servers
resource "azurerm_subnet" "database_flexibleserver_mysql" {
  count = local.enable_mysql_flexible_subnet ? 1 : 0

  name                 = "${local.name_prefix}-db-mysql"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.database_subnet_cidrs.mysql]

  # CRITICAL: Delegate subnet to MySQL Flexible Servers
  # This means ONLY MySQL Flexible Servers can use this subnet
  delegation {
    name = "mysql-flexible-delegation"
    service_delegation {
      name = "Microsoft.DBforMySQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }

  # Service endpoints required for MySQL operations
  service_endpoints = ["Microsoft.Storage"]

  lifecycle {
    ignore_changes = [name]
    # Don't ignore delegation changes as they're critical for functionality
  }
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
