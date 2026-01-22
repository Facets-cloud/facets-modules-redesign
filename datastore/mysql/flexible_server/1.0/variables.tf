variable "instance" {
  description = "Azure Database for MySQL - Flexible Server with high availability and automated backup"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version_config = object({
        version       = string
        database_name = string
        charset       = string
        collation     = string
      })
      sizing = object({
        sku_name           = string
        storage_gb         = number
        iops               = number
        storage_tier       = string
        read_replica_count = number
      })
      restore_config = object({
        restore_from_backup    = optional(bool)
        source_server_id       = optional(string)
        restore_point_in_time  = optional(string)
        administrator_login    = optional(string)
        administrator_password = optional(string)
      })
      imports = optional(object({
        import_existing  = optional(bool, false)
        server_id        = optional(string)
        database_id      = optional(string)
        firewall_rule_id = optional(string)
      }))
    })
  })

  validation {
    condition     = contains(["5.7", "8.0.21", "8.0.37"], var.instance.spec.version_config.version)
    error_message = "MySQL version must be one of: 5.7, 8.0.21, 8.0.37"
  }

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", var.instance.spec.version_config.database_name))
    error_message = "Database name must start with a letter and contain only letters, numbers, and underscores (max 63 characters)"
  }

  validation {
    condition     = contains(["utf8", "utf8mb4", "latin1"], var.instance.spec.version_config.charset)
    error_message = "Character set must be one of: utf8, utf8mb4, latin1"
  }

  validation {
    condition = contains([
      # Burstable SKUs
      "B_Standard_B1s", "B_Standard_B1ms", "B_Standard_B2s", "B_Standard_B2ms", "B_Standard_B4ms",
      # General Purpose SKUs (v4 generation)
      "GP_Standard_D2ds_v4", "GP_Standard_D4ds_v4", "GP_Standard_D8ds_v4", "GP_Standard_D16ds_v4", "GP_Standard_D32ds_v4", "GP_Standard_D48ds_v4", "GP_Standard_D64ds_v4",
      # Memory Optimized SKUs (v4 generation)
      "MO_Standard_E2ds_v4", "MO_Standard_E4ds_v4", "MO_Standard_E8ds_v4", "MO_Standard_E16ds_v4", "MO_Standard_E20ds_v4", "MO_Standard_E32ds_v4", "MO_Standard_E48ds_v4", "MO_Standard_E64ds_v4",
      # Legacy v5 SKUs (if still supported)
      "GP_Standard_D2ds_v5", "GP_Standard_D4ds_v5", "GP_Standard_D8ds_v5", "GP_Standard_D16ds_v5", "GP_Standard_D32ds_v5", "GP_Standard_D48ds_v5", "GP_Standard_D64ds_v5",
      "MO_Standard_E2ds_v5", "MO_Standard_E4ds_v5", "MO_Standard_E8ds_v5", "MO_Standard_E16ds_v5", "MO_Standard_E20ds_v5", "MO_Standard_E32ds_v5", "MO_Standard_E48ds_v5", "MO_Standard_E64ds_v5"
    ], var.instance.spec.sizing.sku_name)
    error_message = "SKU name must be a valid Azure MySQL Flexible Server SKU (e.g., B_Standard_B1ms, GP_Standard_D2ds_v4, MO_Standard_E4ds_v4)"
  }

  validation {
    condition     = var.instance.spec.sizing.storage_gb >= 20 && var.instance.spec.sizing.storage_gb <= 16384
    error_message = "Storage must be between 20 GB and 16,384 GB"
  }

  validation {
    condition     = var.instance.spec.sizing.iops >= 360 && var.instance.spec.sizing.iops <= 20000
    error_message = "IOPS must be between 360 and 20,000"
  }

  validation {
    condition     = contains(["P4", "P6", "P10", "P15", "P20", "P30", "P40", "P50", "P60", "P70", "P80"], var.instance.spec.sizing.storage_tier)
    error_message = "Storage tier must be a valid Azure storage performance tier"
  }

  validation {
    condition     = var.instance.spec.sizing.read_replica_count >= 0 && var.instance.spec.sizing.read_replica_count <= 10
    error_message = "Read replica count must be between 0 and 10"
  }

  validation {
    condition = (
      # If using Burstable SKU, replica count must be 0
      startswith(var.instance.spec.sizing.sku_name, "B_") ? var.instance.spec.sizing.read_replica_count == 0 : true
    )
    error_message = "Read replicas are not supported for Burstable SKUs (B_Standard_B1s, B_Standard_B1ms, B_Standard_B2s). Please set read_replica_count to 0 or use a General Purpose or Memory Optimized SKU."
  }

  validation {
    condition = (
      var.instance.spec.restore_config.restore_from_backup == true ?
      var.instance.spec.restore_config.administrator_password != null && var.instance.spec.restore_config.administrator_password != "" :
      true
    )
    error_message = "When restore_from_backup is enabled, administrator_password must be provided."
  }
}

variable "instance_name" {
  description = "The architectural name for the resource as added in the Facets blueprint designer."
  type        = string
}

variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = map(string)
  })
}

variable "inputs" {
  description = "A map of inputs requested by the module developer."
  type = object({
    azure_provider = object({
      attributes = object({
        subscription_id = string
        client_id       = string
        client_secret   = string
        tenant_id       = string
      })
    })
    network_details = object({
      attributes = object({
        resource_group_name = string
        vnet_id             = string
        vnet_name           = string
        region              = string
        vnet_cidr_block     = string
        private_subnet_ids  = list(string)
        availability_zones  = optional(list(string))
        # MySQL-specific network attributes from azure-network module
        database_mysql_subnet_id = optional(string)
        mysql_dns_zone_id        = optional(string)
      })
    })
  })

  # Validation to ensure MySQL subnet is configured in the network module
  validation {
    condition = (
      var.inputs.network_details.attributes.database_mysql_subnet_id != null &&
      var.inputs.network_details.attributes.database_mysql_subnet_id != ""
    )
    error_message = "The network module must have MySQL Flexible Server subnet enabled (database_config.enable_mysql_flexible_subnet = true)"
  }

  # Validation to ensure MySQL DNS zone is configured in the network module
  validation {
    condition = (
      var.inputs.network_details.attributes.mysql_dns_zone_id != null &&
      var.inputs.network_details.attributes.mysql_dns_zone_id != ""
    )
    error_message = "The network module must have MySQL DNS zone configured (automatically created when MySQL subnet is enabled)"
  }
}