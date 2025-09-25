variable "instance" {
  description = "Custom Azure Cache for Redis - A fully managed in-memory cache service built on open-source Redis, offering high performance and scalability for Azure applications."
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version_config = object({
        redis_version = string
        family        = string
      })
      sizing = object({
        sku_name             = string
        capacity             = number
        replicas_per_master  = optional(number)
        replicas_per_primary = optional(number)
        shard_count          = optional(number)
      })
      terraform_import = optional(object({
        cache_name          = optional(string)
        resource_group_name = optional(string)
      }))
    })
  })

  validation {
    condition     = contains(["4", "6", "7.2"], var.instance.spec.version_config.redis_version)
    error_message = "Redis version must be 4, 6, or 7.2."
  }

  validation {
    condition     = contains(["C", "P"], var.instance.spec.version_config.family)
    error_message = "Family must be C (Basic/Standard) or P (Premium)."
  }

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.instance.spec.sizing.sku_name)
    error_message = "SKU name must be Basic, Standard, or Premium."
  }

  validation {
    condition     = var.instance.spec.sizing.capacity >= 0 && var.instance.spec.sizing.capacity <= 6
    error_message = "Capacity must be between 0 and 6."
  }

  validation {
    condition     = var.instance.spec.version_config.redis_version != "7.2" || var.instance.spec.sizing.sku_name == "Premium"
    error_message = "Redis version 7.2 is only supported with Premium SKU. Use version 4 or 6 for Basic/Standard SKUs."
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
    cloud_tags  = optional(map(string))
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
        resource_group_id            = string
        resource_group_name          = string
        vnet_id                      = string
        vnet_name                    = string
        vnet_cidr_block              = string
        region                       = string
        availability_zones           = list(string)
        public_subnet_ids            = list(string)
        private_subnet_ids           = list(string)
        public_subnet_cidrs          = list(string)
        private_subnet_cidrs         = list(string)
        default_security_group_id    = string
        database_general_subnet_id   = optional(string)
        database_general_subnet_name = optional(string)
        database_general_subnet_cidr = optional(string)
      })
    })
  })
}