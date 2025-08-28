# Local computations for Azure Redis Cache configuration
locals {
  # Basic naming and identification
  cache_name = "${var.instance_name}-${var.environment.unique_name}"

  # Extract configuration values
  redis_version = var.instance.spec.version_config.redis_version
  family        = var.instance.spec.version_config.family
  sku_name      = var.instance.spec.sizing.sku_name
  capacity      = var.instance.spec.sizing.capacity

  # Premium-only configurations with defaults
  replicas_per_master  = lookup(var.instance.spec.sizing, "replicas_per_master", 1)
  replicas_per_primary = lookup(var.instance.spec.sizing, "replicas_per_primary", 1)
  shard_count          = lookup(var.instance.spec.sizing, "shard_count", 1)

  # Restore configuration
  restore_from_backup         = lookup(var.instance.spec.restore_config, "restore_from_backup", false)
  backup_storage_account_name = lookup(var.instance.spec.restore_config, "backup_storage_account_name", "")
  backup_container_name       = lookup(var.instance.spec.restore_config, "backup_container_name", "")
  backup_file_name            = lookup(var.instance.spec.restore_config, "backup_file_name", "")

  # Network details from inputs
  resource_group_name = var.inputs.network_details.attributes.resource_group_name
  subnet_id           = var.inputs.network_details.attributes.private_subnet_ids[0]

  # Security defaults (hardcoded as per standards)
  non_ssl_port_enabled = false
  minimum_tls_version  = "1.2"

  # Redis port configuration
  redis_port     = 6379
  redis_ssl_port = 6380

  # Tags from environment
  tags = lookup(var.environment, "cloud_tags", {})
}

# Azure Redis Cache Resource
resource "azurerm_redis_cache" "main" {
  name                = local.cache_name
  location            = var.inputs.network_details.attributes.region
  resource_group_name = local.resource_group_name

  # Core configuration
  capacity      = local.capacity
  family        = local.family
  sku_name      = local.sku_name
  redis_version = local.redis_version

  # Security configuration (hardcoded secure defaults)
  non_ssl_port_enabled = local.non_ssl_port_enabled
  minimum_tls_version  = local.minimum_tls_version

  # Network configuration (VNet injection only for Premium SKU)
  subnet_id = local.sku_name == "Premium" ? local.subnet_id : null

  # Premium-only configurations using shard_count directly
  shard_count = local.family == "P" ? local.shard_count : null

  # Redis configuration for Premium tier
  redis_configuration {
    maxmemory_policy = "allkeys-lru"
    # Premium features
    rdb_backup_enabled   = local.family == "P" ? true : false
    rdb_backup_frequency = local.family == "P" ? 1440 : null # Daily backups
  }

  # Patch schedule for maintenance
  patch_schedule {
    day_of_week    = "Sunday"
    start_hour_utc = 2
  }

  # Lifecycle configuration for stateful resource
  lifecycle {
    prevent_destroy = true
  }

  tags = local.tags
}

# Firewall rule to allow access from VNet subnets (Premium SKU only)
resource "azurerm_redis_firewall_rule" "vnet_access" {
  count = local.sku_name == "Premium" ? length(var.inputs.network_details.attributes.private_subnet_cidrs) : 0

  name                = "vnet-subnet-${count.index}"
  redis_cache_name    = azurerm_redis_cache.main.name
  resource_group_name = local.resource_group_name

  start_ip = cidrhost(var.inputs.network_details.attributes.private_subnet_cidrs[count.index], 0)
  end_ip   = cidrhost(var.inputs.network_details.attributes.private_subnet_cidrs[count.index], -1)
}