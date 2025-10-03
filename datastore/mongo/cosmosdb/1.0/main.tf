# All local values are defined in locals.tf to avoid duplication

# Random string for unique naming to avoid conflicts
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Data source for existing account (if importing)
data "azurerm_cosmosdb_account" "existing" {
  count               = local.import_account_name != null ? 1 : 0
  name                = local.import_account_name
  resource_group_name = var.inputs.network_details.attributes.resource_group_name
}

# Data source to get restorable account information (for restore operations)
data "azurerm_cosmosdb_restorable_database_accounts" "source" {
  count    = local.is_restore ? 1 : 0
  name     = var.instance.spec.restore_config.source_account_name
  location = var.inputs.network_details.attributes.region
}

# Azure Cosmos DB Account for MongoDB API (Normal Creation)
resource "azurerm_cosmosdb_account" "mongodb" {
  count               = local.import_account_name == null && !local.is_restore ? 1 : 0
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

  # Backup policy - enable continuous backup for point-in-time restore capability
  backup {
    type                = lookup(var.instance.spec.backup_config, "enable_continuous_backup", false) ? "Continuous" : "Periodic"
    interval_in_minutes = lookup(var.instance.spec.backup_config, "enable_continuous_backup", false) ? null : 240 # 4 hours for periodic
    retention_in_hours  = lookup(var.instance.spec.backup_config, "enable_continuous_backup", false) ? null : 168 # 7 days for periodic
  }

  # Security - encryption enabled by default
  public_network_access_enabled = true # Allow public access for testing

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      # Ignore changes that would require recreation for imported resources
      location,
      resource_group_name,
      kind
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

# MongoDB Database
resource "azurerm_cosmosdb_mongo_database" "main" {
  count               = local.import_database_name == null && !local.is_restore ? 1 : 0
  name                = local.database_name
  resource_group_name = var.inputs.network_details.attributes.resource_group_name
  account_name        = local.import_account_name != null ? local.import_account_name : azurerm_cosmosdb_account.mongodb[0].name

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