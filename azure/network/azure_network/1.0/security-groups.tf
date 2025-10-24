#########################################################################
# Network Security Groups                                               #
#########################################################################

# Network Security Group - Allow all within VNet
resource "azurerm_network_security_group" "allow_all_default" {
  name                = "${local.name_prefix}-allow-all-default-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowVnetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.instance.spec.vnet_cidr
    destination_address_prefix = "*"
    description                = "Allowing connection from within vnet"
  }

  tags = merge(local.common_tags, {
    Terraform = "true"
  })

  lifecycle {
    ignore_changes = [name]
  }
}

# Network Security Groups for Subnets - Apply the allow-all NSG to all subnets
resource "azurerm_subnet_network_security_group_association" "public" {
  for_each = azurerm_subnet.public

  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.allow_all_default.id
}

resource "azurerm_subnet_network_security_group_association" "private" {
  for_each = azurerm_subnet.private

  subnet_id                 = each.value.id
  network_security_group_id = azurerm_network_security_group.allow_all_default.id
}

#########################################################################
# Database Subnet Network Security Groups                               #
#########################################################################

# Network Security Group for Database Subnets
# Created when any database subnet is enabled
resource "azurerm_network_security_group" "database" {
  count = (local.enable_general_database_subnet || local.enable_postgresql_flexible_subnet || local.enable_mysql_flexible_subnet) ? 1 : 0

  name                = "${local.name_prefix}-db-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  lifecycle {
    ignore_changes = [name]
  }
}

#########################################################################
# Database NSG Rules - Inbound VNet Traffic                            #
#########################################################################

# Allow all VNet traffic to database subnets
# This single rule replaces specific database port rules since the VNet CIDR
# already provides sufficient isolation and security
resource "azurerm_network_security_rule" "database_vnet_inbound" {
  count = (local.enable_general_database_subnet || local.enable_postgresql_flexible_subnet || local.enable_mysql_flexible_subnet) ? 1 : 0

  name                        = "allow-vnet-inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = var.instance.spec.vnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.database[0].name
  description                 = "Allow all traffic from within VNet CIDR"
}

#########################################################################
# Database NSG Rules - Common Outbound Rules                            #
#########################################################################

# Allow Storage access for backups - needed by all database types
resource "azurerm_network_security_rule" "storage_outbound" {
  count = (local.enable_general_database_subnet || local.enable_postgresql_flexible_subnet || local.enable_mysql_flexible_subnet) ? 1 : 0

  name                        = "allow-storage-outbound"
  priority                    = 200
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "Storage"
  resource_group_name         = azurerm_resource_group.main.name
  network_security_group_name = azurerm_network_security_group.database[0].name
  description                 = "Allow access to Azure Storage for database backups"
}

# Allow Azure Active Directory for authentication
resource "azurerm_network_security_rule" "azure_ad_outbound" {
  count = (local.enable_general_database_subnet || local.enable_postgresql_flexible_subnet || local.enable_mysql_flexible_subnet) ? 1 : 0

  name                        = "allow-azuread-outbound"
  priority                    = 201
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
  count = (local.enable_general_database_subnet || local.enable_postgresql_flexible_subnet || local.enable_mysql_flexible_subnet) ? 1 : 0

  name                        = "allow-azuremonitor-outbound"
  priority                    = 202
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

#########################################################################
# Database NSG Associations                                             #
#########################################################################

# Associate NSG with General Database Subnet
resource "azurerm_subnet_network_security_group_association" "database_general" {
  count = local.enable_general_database_subnet ? 1 : 0

  subnet_id                 = azurerm_subnet.database_subnets[0].id
  network_security_group_id = azurerm_network_security_group.database[0].id
}

# Associate NSG with PostgreSQL Subnet
resource "azurerm_subnet_network_security_group_association" "database_postgresql" {
  count = local.enable_postgresql_flexible_subnet ? 1 : 0

  subnet_id                 = azurerm_subnet.database_flexibleserver_postgresql[0].id
  network_security_group_id = azurerm_network_security_group.database[0].id
}

# Associate NSG with MySQL Subnet
resource "azurerm_subnet_network_security_group_association" "database_mysql" {
  count = local.enable_mysql_flexible_subnet ? 1 : 0

  subnet_id                 = azurerm_subnet.database_flexibleserver_mysql[0].id
  network_security_group_id = azurerm_network_security_group.database[0].id
}

# Note: Database subnets use a single inbound rule that allows all traffic from within the VNet CIDR.
# This approach is consistent with the allow_all_default NSG and avoids redundant port-specific rules.
