#########################################################################
# Database Subnet Resources                                             #
# Includes general database subnet and delegated subnets               #
#########################################################################

# General Database Subnet - No delegation, for resources that don't require it
resource "azurerm_subnet" "database_general" {
  count = local.enable_database_subnets ? 1 : 0

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

  # Enable private endpoints in this subnet
  # Set to "Disabled" to allow private endpoints (naming is counterintuitive)
  private_endpoint_network_policies = "Disabled"

  # Enable private link service
  private_link_service_network_policies_enabled = false

  lifecycle {
    ignore_changes = [service_endpoints, name]
  }
}

# PostgreSQL Delegated Subnet - ONLY for PostgreSQL Flexible Servers
resource "azurerm_subnet" "database_postgresql" {
  count = local.enable_database_subnets ? 1 : 0

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

# MySQL Delegated Subnet - ONLY for MySQL Flexible Servers
resource "azurerm_subnet" "database_mysql" {
  count = local.enable_database_subnets ? 1 : 0

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

# Network Security Group for Database Subnets
resource "azurerm_network_security_group" "database" {
  count = local.enable_database_subnets ? 1 : 0

  name                = "${local.name_prefix}-db-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# NSG Rules for PostgreSQL
resource "azurerm_network_security_rule" "postgresql_inbound" {
  count = local.enable_database_subnets ? 1 : 0

  name                        = "allow-postgresql-vnet"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "5432"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.database[0].name
}

# NSG Rules for MySQL
resource "azurerm_network_security_rule" "mysql_inbound" {
  count = local.enable_database_subnets ? 1 : 0

  name                        = "allow-mysql-vnet"
  priority                    = 101
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3306"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.database[0].name
}

# Allow Storage access for backups
resource "azurerm_network_security_rule" "storage_outbound" {
  count = local.enable_database_subnets ? 1 : 0

  name                        = "allow-storage-outbound"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Storage"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.database[0].name
}

# Allow Azure Active Directory for authentication
resource "azurerm_network_security_rule" "azure_ad_outbound" {
  count = local.enable_database_subnets ? 1 : 0

  name                        = "allow-azuread-outbound"
  priority                    = 101
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["443", "445"]
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureActiveDirectory"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.database[0].name
  description                 = "Allow Azure AD authentication for databases"
}

# Allow Azure Monitor for metrics and logging
resource "azurerm_network_security_rule" "azure_monitor_outbound" {
  count = local.enable_database_subnets ? 1 : 0

  name                        = "allow-azuremonitor-outbound"
  priority                    = 102
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["443"]
  source_address_prefix       = "*"
  destination_address_prefix  = "AzureMonitor"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.database[0].name
  description                 = "Allow Azure Monitor for database metrics and logging"
}

# Allow internal database communication for HA and replication
resource "azurerm_network_security_rule" "database_internal" {
  count = local.enable_database_subnets ? 1 : 0

  name                   = "allow-database-internal"
  priority               = 102
  direction              = "Inbound"
  access                 = "Allow"
  protocol               = "*"
  source_port_range      = "*"
  destination_port_range = "*"
  source_address_prefixes = [
    local.database_subnet_cidrs.general,
    local.database_subnet_cidrs.postgresql,
    local.database_subnet_cidrs.mysql
  ]
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.database[0].name
  description                 = "Allow communication between database subnets for HA and replication"
}

# Associate NSG with General Database Subnet
resource "azurerm_subnet_network_security_group_association" "database_general" {
  count = local.enable_database_subnets ? 1 : 0

  subnet_id                 = azurerm_subnet.database_general[0].id
  network_security_group_id = azurerm_network_security_group.database[0].id
}

# Associate NSG with PostgreSQL Subnet
resource "azurerm_subnet_network_security_group_association" "database_postgresql" {
  count = local.enable_database_subnets ? 1 : 0

  subnet_id                 = azurerm_subnet.database_postgresql[0].id
  network_security_group_id = azurerm_network_security_group.database[0].id
}

# Associate NSG with MySQL Subnet
resource "azurerm_subnet_network_security_group_association" "database_mysql" {
  count = local.enable_database_subnets ? 1 : 0

  subnet_id                 = azurerm_subnet.database_mysql[0].id
  network_security_group_id = azurerm_network_security_group.database[0].id
}

# Note: Delegated subnets for PostgreSQL and MySQL handle their own routing
# The general database subnet uses the private subnet route table for consistency
# This ensures private endpoints in the general subnet can reach internet via NAT Gateway

# Associate general database subnet with private route table for NAT Gateway routing
resource "azurerm_subnet_route_table_association" "database_general" {
  count = local.enable_database_subnets ? 1 : 0

  subnet_id      = azurerm_subnet.database_general[0].id
  route_table_id = var.instance.spec.nat_gateway.strategy == "per_az" ? azurerm_route_table.private["1"].id : azurerm_route_table.private["single"].id
}

# Note: PostgreSQL and MySQL delegated subnets do NOT need route table associations
# Azure manages routing for delegated subnets automatically
