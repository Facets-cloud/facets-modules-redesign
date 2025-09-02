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
