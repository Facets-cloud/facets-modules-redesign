# All local values are defined in locals.tf to avoid duplication

# Random string for unique naming to avoid conflicts
# Only create when NOT importing (imports use existing resources with existing names)
resource "random_string" "suffix" {
  count   = local.is_import ? 0 : 1
  length  = 6
  special = false
  upper   = false
}

# Data source to get restorable account information (for restore operations)
data "azurerm_cosmosdb_restorable_database_accounts" "source" {
  count    = local.is_restore ? 1 : 0
  name     = var.instance.spec.restore_config.source_account_name
  location = var.inputs.network_details.attributes.region
}

# Azure Cosmos DB Account for MongoDB API (Normal Creation or Import)
resource "azurerm_cosmosdb_account" "mongodb" {
  count               = !local.is_restore ? 1 : 0
  name                = local.account_name
  location            = var.inputs.network_details.attributes.region
  resource_group_name = var.inputs.network_details.attributes.resource_group_name
  offer_type          = "Standard"
  kind                = "MongoDB"

  # MongoDB API version
  mongo_server_version = var.instance.spec.version_config.api_version

  # Automatic failover configuration
  automatic_failover_enabled = true

  # Default consistency level
  consistency_policy {
    consistency_level       = title(var.instance.spec.version_config.consistency_level)
    max_interval_in_seconds = var.instance.spec.version_config.consistency_level == "bounded_staleness" ? 300 : null
    max_staleness_prefix    = var.instance.spec.version_config.consistency_level == "bounded_staleness" ? 100000 : null
  }

  # Primary geo location
  geo_location {
    location          = var.inputs.network_details.attributes.region
    failover_priority = 0
    zone_redundant    = false # Disabled to avoid regional availability issues
  }

  # Additional geo locations for multi-region setup
  dynamic "geo_location" {
    for_each = var.instance.spec.sizing.enable_multi_region ? ["secondary"] : []
    content {
      location          = "East US" # Default secondary region
      failover_priority = 1
      zone_redundant    = false # Disabled to avoid regional availability issues
    }
  }

  # Backup policy - only set when NOT importing (imports inherit existing backup policy)
  dynamic "backup" {
    for_each = local.is_import ? [] : [1]
    content {
      type                = lookup(var.instance.spec.backup_config, "enable_continuous_backup", false) ? "Continuous" : "Periodic"
      interval_in_minutes = lookup(var.instance.spec.backup_config, "enable_continuous_backup", false) ? null : 240 # 4 hours for periodic
      retention_in_hours  = lookup(var.instance.spec.backup_config, "enable_continuous_backup", false) ? null : 168 # 7 days for periodic
    }
  }

  # Security - encryption enabled by default
  public_network_access_enabled = true # Allow public access for testing

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
    # Always ignore these to prevent recreation
    ignore_changes = [
      location,
      resource_group_name,
      kind,
      backup,
      consistency_policy,
      geo_location,
      mongo_server_version
    ]
  }

  tags = merge(var.environment.cloud_tags, {
    Name   = local.account_name
    Type   = "MongoDB"
    Flavor = "CosmosDB"
  })
}

# Azure Cosmos DB Account for MongoDB API (Restored from Backup)
resource "azurerm_cosmosdb_account" "mongodb_restored" {
  count               = local.is_restore ? 1 : 0
  name                = local.account_name
  location            = var.inputs.network_details.attributes.region
  resource_group_name = var.inputs.network_details.attributes.resource_group_name
  offer_type          = "Standard"
  kind                = "MongoDB"

  # Enable restore mode
  create_mode = "Restore"

  # Restore configuration  
  # The data source returns a list of restorable accounts, we need the first one's ID
  restore {
    source_cosmosdb_account_id = try(data.azurerm_cosmosdb_restorable_database_accounts.source[0].accounts[0].id, "")
    restore_timestamp_in_utc   = var.instance.spec.restore_config.restore_timestamp
  }

  # MongoDB API version
  mongo_server_version = var.instance.spec.version_config.api_version

  # Automatic failover configuration
  automatic_failover_enabled = true

  # Default consistency level
  consistency_policy {
    consistency_level       = title(var.instance.spec.version_config.consistency_level)
    max_interval_in_seconds = var.instance.spec.version_config.consistency_level == "bounded_staleness" ? 300 : null
    max_staleness_prefix    = var.instance.spec.version_config.consistency_level == "bounded_staleness" ? 100000 : null
  }

  # Primary geo location
  geo_location {
    location          = var.inputs.network_details.attributes.region
    failover_priority = 0
    zone_redundant    = false
  }

  # Additional geo locations for multi-region setup
  dynamic "geo_location" {
    for_each = var.instance.spec.sizing.enable_multi_region ? ["secondary"] : []
    content {
      location          = "East US" # Default secondary region
      failover_priority = 1
      zone_redundant    = false
    }
  }

  # NOTE: When using create_mode = "Restore", we must specify backup type as Continuous
  # The provider requires this even though backup settings are inherited from source
  backup {
    type = "Continuous"
    # No other backup parameters should be specified for restore operations
  }

  # Security - encryption enabled by default
  public_network_access_enabled = true

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
  }

  tags = merge(var.environment.cloud_tags, {
    Name     = local.account_name
    Type     = "MongoDB"
    Flavor   = "CosmosDB"
    Restored = "true"
  })
}

# MongoDB Database (Normal Creation or Import)
resource "azurerm_cosmosdb_mongo_database" "main" {
  count               = local.database_count
  name                = local.database_name
  resource_group_name = var.inputs.network_details.attributes.resource_group_name
  # When importing, use the import account name directly to avoid dependency on account resource
  account_name = local.is_import ? local.import_account_name : azurerm_cosmosdb_account.mongodb[0].name

  # Throughput configuration - only set when NOT importing
  dynamic "autoscale_settings" {
    for_each = !local.is_import && var.instance.spec.sizing.throughput_mode == "provisioned" ? [1] : []
    content {
      max_throughput = var.instance.spec.sizing.max_throughput
    }
  }

  lifecycle {
    prevent_destroy = true
    # Always ignore throughput changes to prevent drift
    ignore_changes = [autoscale_settings, throughput]
  }
}

# MongoDB Database for Restored Account
resource "azurerm_cosmosdb_mongo_database" "main_restored" {
  count               = local.is_restore ? 1 : 0
  name                = local.database_name
  resource_group_name = var.inputs.network_details.attributes.resource_group_name
  account_name        = azurerm_cosmosdb_account.mongodb_restored[0].name

  # Throughput configuration
  dynamic "autoscale_settings" {
    for_each = var.instance.spec.sizing.throughput_mode == "provisioned" ? [1] : []
    content {
      max_throughput = var.instance.spec.sizing.max_throughput
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}