locals {
  output_attributes = {
    resource_group_id               = azurerm_resource_group.main.id
    resource_group_name             = azurerm_resource_group.main.name
    vnet_id                         = azurerm_virtual_network.main.id
    vnet_name                       = azurerm_virtual_network.main.name
    vnet_cidr_block                 = var.instance.spec.vnet_cidr
    region                          = azurerm_resource_group.main.location
    availability_zones              = var.instance.spec.availability_zones
    nat_gateway_ids                 = values(azurerm_nat_gateway.main)[*].id
    nat_gateway_public_ip_ids       = values(azurerm_public_ip.nat_gateway)[*].id
    public_subnet_ids               = values(azurerm_subnet.public)[*].id
    private_subnet_ids              = values(azurerm_subnet.private)[*].id
    public_subnet_cidrs             = [for subnet in local.public_subnets : subnet.cidr_block]
    private_subnet_cidrs            = [for subnet in local.private_subnets : subnet.cidr_block]
    default_security_group_id       = azurerm_network_security_group.allow_all_default.id
    database_general_subnet_id      = local.enable_database_subnets ? azurerm_subnet.database_general[0].id : null
    database_general_subnet_name    = local.enable_database_subnets ? azurerm_subnet.database_general[0].name : null
    database_general_subnet_cidr    = local.enable_database_subnets ? local.database_subnet_cidrs.general : null
    database_postgresql_subnet_id   = local.enable_database_subnets ? azurerm_subnet.database_postgresql[0].id : null
    database_postgresql_subnet_name = local.enable_database_subnets ? azurerm_subnet.database_postgresql[0].name : null
    database_postgresql_subnet_cidr = local.enable_database_subnets ? local.database_subnet_cidrs.postgresql : null
    database_mysql_subnet_id        = local.enable_database_subnets ? azurerm_subnet.database_mysql[0].id : null
    database_mysql_subnet_name      = local.enable_database_subnets ? azurerm_subnet.database_mysql[0].name : null
    database_mysql_subnet_cidr      = local.enable_database_subnets ? local.database_subnet_cidrs.mysql : null
    postgresql_dns_zone_id          = local.create_postgresql_dns_zone ? azurerm_private_dns_zone.postgresql[0].id : null
    postgresql_dns_zone_name        = local.create_postgresql_dns_zone ? azurerm_private_dns_zone.postgresql[0].name : null
    mysql_dns_zone_id               = local.create_mysql_dns_zone ? azurerm_private_dns_zone.mysql[0].id : null
    mysql_dns_zone_name             = local.create_mysql_dns_zone ? azurerm_private_dns_zone.mysql[0].name : null
  }
}