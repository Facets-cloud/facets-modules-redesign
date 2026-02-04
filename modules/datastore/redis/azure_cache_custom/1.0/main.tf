# Local computations for Azure Redis Cache configuration
locals {
  # Import detection
  import_enabled = lookup(var.instance.spec, "imports", null) != null ? lookup(var.instance.spec.imports, "import_existing", false) : false

  # Import configuration - expects full Azure resource ID
  # Normalize case: Azure returns Microsoft.Cache/Redis but Terraform expects Microsoft.Cache/redis
  import_cache_id_raw = local.import_enabled && lookup(var.instance.spec.imports, "cache_resource_id", null) != null ? var.instance.spec.imports.cache_resource_id : null
  import_cache_id     = local.import_cache_id_raw

  # Extract cache name from resource ID for use in Terraform configs
  # Format: /subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Cache/redis/{name}
  import_cache_name = local.import_cache_id != null ? element(split("/", local.import_cache_id), length(split("/", local.import_cache_id)) - 1) : null

  # Mode detection
  is_import = local.import_enabled && local.import_cache_id != null

  # Basic naming and identification
  cache_name = local.is_import ? local.import_cache_name : "${var.instance_name}-${var.environment.unique_name}"

  # Extract configuration values
  redis_version = var.instance.spec.version_config.redis_version
  family        = var.instance.spec.version_config.family
  sku_name      = var.instance.spec.sizing.sku_name
  capacity      = var.instance.spec.sizing.capacity

  # Premium-only configurations with defaults
  replicas_per_master  = lookup(var.instance.spec.sizing, "replicas_per_master", 1)
  replicas_per_primary = lookup(var.instance.spec.sizing, "replicas_per_primary", 1)
  shard_count          = lookup(var.instance.spec.sizing, "shard_count", 1)

  # Network details from inputs
  resource_group_name = var.inputs.network_details.attributes.resource_group_name

  # Use database subnet if available, otherwise fall back to private subnet
  # This provides better isolation for database resources when database subnets are enabled
  subnet_id = coalesce(
    var.inputs.network_details.attributes.database_general_subnet_id,
    var.inputs.network_details.attributes.private_subnet_ids[0]
  )

  # Security defaults (hardcoded as per standards)
  non_ssl_port_enabled = false
  minimum_tls_version  = "1.2"

  # Redis port configuration
  redis_port     = 6379
  redis_ssl_port = 6380

  # Tags from environment
  tags = lookup(var.environment, "cloud_tags", {})

  # Generate unique storage account name with timestamp (must be unique and <= 24 chars)
  # Format: {cache-name-prefix}bk{timestamp} where timestamp is in YYMMDDhhmm format
  timestamp_suffix = formatdate("YYMMDDhhmm", timestamp())
  cache_name_clean = replace(local.cache_name, "-", "")

  # Calculate max prefix length to accommodate 'bk' + 10-char timestamp
  max_prefix_length = 24 - 2 - 10 # 24 total - 'bk' - timestamp
  cache_prefix      = substr(local.cache_name_clean, 0, local.max_prefix_length)

  # Final storage name: {cache_prefix}bk{timestamp}
  backup_storage_name = "${local.cache_prefix}bk${local.timestamp_suffix}"

  # Premium SKU always needs backup storage - but not when importing
  is_premium            = local.sku_name == "Premium"
  create_backup_storage = local.is_premium && !local.is_import

  # Validation: Ensure storage account name doesn't exceed Azure limits
  storage_name_valid = length(local.backup_storage_name) <= 24 && length(local.backup_storage_name) >= 3

  # Debug information for storage name generation
  storage_name_debug = {
    generated_name    = local.backup_storage_name
    name_length       = length(local.backup_storage_name)
    is_valid          = local.storage_name_valid
    cache_prefix      = local.cache_prefix
    timestamp         = local.timestamp_suffix
    max_prefix_length = local.max_prefix_length
  }

  # Determine which subnets need firewall access
  # If using database subnet, include it; otherwise use private subnets
  using_database_subnet = var.inputs.network_details.attributes.database_general_subnet_id != null && var.inputs.network_details.attributes.database_general_subnet_id != ""

  # Create list of subnet CIDRs that need access
  firewall_subnet_cidrs = local.using_database_subnet ? (
    # When using database subnet, only allow access from that subnet
    compact([var.inputs.network_details.attributes.database_general_subnet_cidr])
    ) : (
    # When not using database subnet, allow access from all private subnets
    var.inputs.network_details.attributes.private_subnet_cidrs
  )
}

# Backup Storage Account (created for Premium SKU)
# Premium SKU always requires storage for RDB backups
resource "azurerm_storage_account" "backup" {
  count = local.create_backup_storage ? 1 : 0

  name                     = local.backup_storage_name
  resource_group_name      = local.resource_group_name
  location                 = var.inputs.network_details.attributes.region
  account_tier             = "Standard"
  account_replication_type = "GRS"
  account_kind             = "StorageV2"

  # Security settings
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  # Blob properties for testing (minimal retention for easy cleanup)
  blob_properties {
    # Disable soft delete for easier testing cleanup
    delete_retention_policy {
      days = 1 # Minimum allowed value
    }
    # Disable versioning to avoid extra cleanup complexity
    versioning_enabled = false
  }

  # Lifecycle configuration with validation
  lifecycle {
    prevent_destroy = true

    # Validate storage account name length
    precondition {
      condition     = length(local.backup_storage_name) <= 24 && length(local.backup_storage_name) >= 3
      error_message = "Generated storage account name '${local.backup_storage_name}' (${length(local.backup_storage_name)} chars) must be between 3 and 24 characters. Please use a shorter instance name."
    }
  }

  tags = local.tags
}

# Backup Container (created for Premium SKU backups)
resource "azurerm_storage_container" "backup" {
  count = local.create_backup_storage ? 1 : 0

  name                  = "redis-backups"
  storage_account_id    = azurerm_storage_account.backup[count.index].id
  container_access_type = "private"
}

# Generate backup storage connection string
# Premium SKU always needs this for RDB backups
locals {
  backup_storage_connection_string = local.is_premium && local.create_backup_storage ? "DefaultEndpointsProtocol=https;BlobEndpoint=${azurerm_storage_account.backup[0].primary_blob_endpoint};AccountName=${azurerm_storage_account.backup[0].name};AccountKey=${azurerm_storage_account.backup[0].primary_access_key}" : ""
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

  # Redis configuration
  redis_configuration {
    maxmemory_policy = "allkeys-lru"

    # Only set backup configuration for Premium SKU and when NOT importing
    # Let Azure handle the max snapshot count automatically
    rdb_backup_enabled            = local.family == "P" && !local.is_import ? true : null
    rdb_backup_frequency          = local.family == "P" && !local.is_import ? 1440 : null
    rdb_storage_connection_string = local.family == "P" && !local.is_import ? local.backup_storage_connection_string : null
  }

  # Patch schedule for maintenance
  patch_schedule {
    day_of_week    = "Sunday"
    start_hour_utc = 2
  }

  # Lifecycle configuration
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      name,
      location,
      resource_group_name,
      subnet_id,
      redis_configuration,
      capacity,
      family,
      sku_name,
      redis_version,
      shard_count,
      patch_schedule,
      non_ssl_port_enabled,
      minimum_tls_version,
      tags
    ]
  }

  # Ensure storage is created before Redis cache for Premium SKU
  depends_on = [
    azurerm_storage_account.backup,
    azurerm_storage_container.backup
  ]

  tags = local.tags
}

# IMPORTANT: Data Import/Restore Instructions for Premium SKU
# =============================================================
# Azure Redis Cache does NOT support automatic restore from RDB files during Terraform creation.
# Unlike MySQL/PostgreSQL Flexible Servers, Redis Cache import is a manual post-deployment process.
#
# To import data from an RDB backup file (Premium SKU only):
# 1. Ensure your Redis Cache has been created successfully (terraform apply)
# 2. Upload your RDB backup file to the storage container created by this module:
#    - Storage Account: ${local.backup_storage_name} (created automatically for Premium SKU)
#    - Container Name: redis-backups
# 3. Navigate to Azure Portal:
#    - Go to your Redis Cache instance
#    - Select "Administration" > "Import Data" from the left menu
#    - Choose your RDB file from the storage container
#    - Click "Import" to start the restore process
# 4. Monitor the import progress in the Azure Portal notifications
#
# Note: The import feature is ONLY available for Premium tier caches.
# Basic and Standard tiers do NOT support import/export functionality.

# Firewall rule to allow access from appropriate subnets (Premium SKU only)
# Uses database subnet if available, otherwise private subnets
resource "azurerm_redis_firewall_rule" "vnet_access" {
  count = local.sku_name == "Premium" ? length(local.firewall_subnet_cidrs) : 0

  name                = local.using_database_subnet ? "database_subnet_${count.index}" : "vnet_subnet_${count.index}"
  redis_cache_name    = azurerm_redis_cache.main.name
  resource_group_name = local.resource_group_name

  start_ip = cidrhost(local.firewall_subnet_cidrs[count.index], 0)
  end_ip   = cidrhost(local.firewall_subnet_cidrs[count.index], -1)

  lifecycle {
    ignore_changes = [
      name,
      redis_cache_name,
      resource_group_name,
      start_ip,
      end_ip
    ]
  }
}