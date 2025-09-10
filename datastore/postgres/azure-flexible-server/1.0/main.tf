# Generate random password for PostgreSQL admin
resource "random_password" "admin_password" {
  length  = 16
  special = true
}

# Data source to get VNet information  
data "azurerm_virtual_network" "vnet" {
  name                = local.vnet_name
  resource_group_name = local.resource_group_name
}

# Data source to get ALL existing subnets in the VNet by name
data "azurerm_subnet" "all_existing_subnets" {
  count                = length(data.azurerm_virtual_network.vnet.subnets)
  name                 = data.azurerm_virtual_network.vnet.subnets[count.index]
  virtual_network_name = local.vnet_name
  resource_group_name  = local.resource_group_name
}

# Simplified and reliable CIDR allocation - no complex loops
locals {
  # Get ALL existing subnet CIDRs from the VNet
  all_existing_subnet_cidrs = data.azurerm_subnet.all_existing_subnets[*].address_prefixes[0]

  # Calculate VNet prefix length (e.g., /16 → 16)  
  vnet_prefix_length = tonumber(split("/", local.vnet_cidr_block)[1])

  # We need /28 subnet (16 IPs, minimum for PostgreSQL Flexible Server)
  subnet_bits_needed = 28 - local.vnet_prefix_length

  # Create deterministic but unique subnet number based on instance name
  # This ensures same instance name gets same CIDR, different instances get different CIDRs
  instance_hash         = substr(sha256("${var.instance_name}-${var.environment.unique_name}"), 0, 8)
  instance_hash_numeric = abs(parseint(local.instance_hash, 16))

  # Use a practical range to avoid Terraform's 1024 limit
  # Most VNets don't need thousands of /28 subnets
  practical_subnet_range = min(1024, pow(2, local.subnet_bits_needed))

  # Start from high range and use deterministic selection to avoid conflicts
  # This greatly reduces chance of conflicts with typical user subnets (0-100)
  base_subnet_num = (local.practical_subnet_range - 100) + (local.instance_hash_numeric % 100)

  # Calculate the PostgreSQL subnet CIDR
  postgres_subnet_cidr = cidrsubnet(local.vnet_cidr_block, local.subnet_bits_needed, local.base_subnet_num)

  # Final CIDR to use for the subnet
  final_postgres_subnet_cidr = local.postgres_subnet_cidr
}

# Create dedicated delegated subnet for PostgreSQL Flexible Server
# This subnet can ONLY be used by PostgreSQL Flexible Servers
resource "azurerm_subnet" "postgres_delegated" {
  name                 = local.postgres_subnet_name
  resource_group_name  = local.resource_group_name
  virtual_network_name = local.vnet_name

  # Use calculated /28 subnet that doesn't overlap with existing subnets
  address_prefixes = [local.final_postgres_subnet_cidr]

  # CRITICAL: Delegate subnet to PostgreSQL Flexible Servers
  # This delegation is REQUIRED and means only PostgreSQL can use this subnet
  delegation {
    name = "postgres-delegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }

  # Service endpoints for storage (required for backup and other operations)
  service_endpoints = ["Microsoft.Storage"]

  lifecycle {
    prevent_destroy = false
  }

  depends_on = [
    data.azurerm_subnet.all_existing_subnets
  ]
}

# Create Private DNS Zone for PostgreSQL (only if create_dns_zone is true - first deployment)
resource "azurerm_private_dns_zone" "postgres" {
  count               = local.create_dns_zone ? 1 : 0
  name                = local.postgres_dns_zone_name
  resource_group_name = local.resource_group_name
  tags                = local.common_tags
}

# Reference existing Private DNS Zone (when create_dns_zone is false - subsequent deployments)
data "azurerm_private_dns_zone" "existing" {
  count               = local.create_dns_zone ? 0 : 1
  name                = local.postgres_dns_zone_name
  resource_group_name = local.resource_group_name
}

# Link Private DNS Zone to VNet (only create if we're managing the DNS zone)
resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  count                 = local.create_dns_zone ? 1 : 0
  name                  = "${local.postgres_subnet_name}-dns-link"
  resource_group_name   = local.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres[0].name
  virtual_network_id    = data.azurerm_virtual_network.vnet.id
  tags                  = local.common_tags
}

# PostgreSQL Flexible Server - With properly delegated subnet
resource "azurerm_postgresql_flexible_server" "main" {
  name                = local.resource_name
  resource_group_name = local.resource_group_name
  location            = local.location

  administrator_login    = local.is_restore ? null : local.admin_username
  administrator_password = local.is_restore ? null : local.admin_password

  sku_name   = local.sku_name
  version    = local.postgres_version
  storage_mb = local.storage_gb * 1024

  backup_retention_days        = local.backup_retention_days
  geo_redundant_backup_enabled = local.geo_redundant_backup_enabled

  # Network configuration - Use our delegated subnet
  delegated_subnet_id = azurerm_subnet.postgres_delegated.id
  private_dns_zone_id = local.postgres_dns_zone_id

  # CRITICAL: Disable public network access when using VNet integration
  # This prevents the "ConflictingPublicNetworkAccessAndVirtualNetworkConfiguration" error
  public_network_access_enabled = false

  # Restore configuration
  source_server_id                  = local.is_restore ? local.source_server_id : null
  point_in_time_restore_time_in_utc = local.is_restore && local.restore_time != null ? local.restore_time : null
  create_mode                       = local.is_restore ? "PointInTimeRestore" : "Default"

  tags = local.common_tags

  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      zone,
      administrator_password,
      # Ignore changes that would require recreation
      delegated_subnet_id,
      private_dns_zone_id,
      # Ignore restore-related attributes that change after restore
      create_mode,
      source_server_id,
      point_in_time_restore_time_in_utc
    ]
  }

  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.postgres,
    data.azurerm_private_dns_zone.existing
  ]
}

# Create default database - conditional creation to handle existing "postgres" database
# Skip database creation during restore as Azure automatically restores all databases
resource "azurerm_postgresql_flexible_server_database" "databases" {
  count     = local.is_restore ? 0 : (local.database_name == "postgres" ? 0 : 1)
  name      = local.database_name
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

# PostgreSQL Flexible Server Configuration for security - version-compatible settings only
resource "azurerm_postgresql_flexible_server_configuration" "log_connections" {
  name      = "log_connections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

resource "azurerm_postgresql_flexible_server_configuration" "log_disconnections" {
  name      = "log_disconnections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "on"
}

# Note: connection_throttling is not supported in PostgreSQL 15+ on Azure Flexible Server
# Removed to prevent configuration errors

# Read replicas - only create if count > 0
resource "azurerm_postgresql_flexible_server" "replicas" {
  count = local.replica_count

  name                = "${local.resource_name}-replica-${count.index + 1}"
  resource_group_name = local.resource_group_name
  location            = local.location

  create_mode      = "Replica"
  source_server_id = azurerm_postgresql_flexible_server.main.id

  # Network configuration - Use same delegated subnet
  delegated_subnet_id = azurerm_subnet.postgres_delegated.id
  private_dns_zone_id = local.postgres_dns_zone_id

  # CRITICAL: Disable public network access when using VNet integration (consistent with primary)
  public_network_access_enabled = false

  tags = merge(local.common_tags, {
    Role = "ReadReplica"
  })

  lifecycle {
    prevent_destroy = false
    ignore_changes = [
      # Ignore changes that would require recreation
      delegated_subnet_id,
      private_dns_zone_id
    ]
  }

  depends_on = [
    azurerm_postgresql_flexible_server.main
  ]
}
