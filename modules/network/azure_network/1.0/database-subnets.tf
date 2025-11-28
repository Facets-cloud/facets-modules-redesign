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

# Note: Database subnet routing is managed in routing.tf along with other subnet route associations
