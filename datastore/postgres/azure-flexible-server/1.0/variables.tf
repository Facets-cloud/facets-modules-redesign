variable "instance" {
  description = "A developer-friendly PostgreSQL flexible server with secure defaults and restore capabilities"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version_config = object({
        version = string
        tier    = string
      })
      sizing = object({
        sku_name           = string
        storage_gb         = number
        read_replica_count = number
      })
      restore_config = optional(object({
        restore_from_backup   = optional(bool, false)
        source_server_id      = optional(string)
        restore_point_in_time = optional(string)
        admin_password        = optional(string)
      }), {})
      imports = optional(object({
        flexible_server_id   = optional(string)
        postgres_database_id = optional(string)
        admin_password       = optional(string)
      }), {})
    })
  })

  validation {
    condition     = contains(["13", "14", "15"], var.instance.spec.version_config.version)
    error_message = "PostgreSQL version must be one of: 13, 14, 15."
  }

  validation {
    condition     = contains(["Burstable", "GeneralPurpose", "MemoryOptimized"], var.instance.spec.version_config.tier)
    error_message = "Performance tier must be one of: Burstable, GeneralPurpose, MemoryOptimized."
  }

  validation {
    condition = contains([
      "B_Standard_B1ms", "B_Standard_B2s", "GP_Standard_D2s_v3",
      "GP_Standard_D4s_v3", "GP_Standard_D8s_v3", "MO_Standard_E2s_v3",
      "MO_Standard_E4s_v3"
    ], var.instance.spec.sizing.sku_name)
    error_message = "SKU name must be a valid Azure PostgreSQL Flexible Server SKU."
  }

  validation {
    condition     = var.instance.spec.sizing.storage_gb >= 32 && var.instance.spec.sizing.storage_gb <= 16384
    error_message = "Storage size must be between 32 and 16384 GB."
  }

  validation {
    condition     = var.instance.spec.sizing.read_replica_count >= 0 && var.instance.spec.sizing.read_replica_count <= 5
    error_message = "Read replica count must be between 0 and 5."
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
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  description = "A map of inputs requested by the module developer."
  type = object({
    azure_provider = object({
      attributes = object({
        client_id       = string
        client_secret   = string
        subscription_id = string
        tenant_id       = string
      })
    })
    network_details = object({
      attributes = object({
        resource_group_name             = string
        vnet_id                         = string
        vnet_name                       = string
        region                          = string
        vnet_cidr_block                 = string
        private_subnet_ids              = list(string)
        availability_zones              = optional(list(string))
        database_postgresql_subnet_id   = optional(string)
        database_postgresql_subnet_name = optional(string)
        database_postgresql_subnet_cidr = optional(string)
        postgresql_dns_zone_id          = optional(string)
        postgresql_dns_zone_name        = optional(string)
      })
    })
  })

  # Validation to ensure PostgreSQL subnet and DNS zone are provided
  validation {
    condition = (
      var.inputs.network_details.attributes.database_postgresql_subnet_id != null &&
      var.inputs.network_details.attributes.database_postgresql_subnet_id != ""
    )
    error_message = "Network details must provide database_postgresql_subnet_id. Ensure the network module has 'database_config.enable_postgresql_flexible_subnet' set to true."
  }

  validation {
    condition = (
      var.inputs.network_details.attributes.postgresql_dns_zone_id != null &&
      var.inputs.network_details.attributes.postgresql_dns_zone_id != ""
    )
    error_message = "Network details must provide postgresql_dns_zone_id. Ensure the network module has 'database_config.enable_postgresql_flexible_subnet' set to true."
  }
}