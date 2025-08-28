variable "instance" {
  description = "MongoDB-compatible database using Azure Cosmos DB service"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version_config = object({
        api_version       = string
        consistency_level = string
        port              = number
      })
      sizing = object({
        throughput_mode     = string
        max_throughput      = number
        enable_multi_region = bool
      })
      restore_config = optional(object({
        restore_from_backup = optional(bool)
        source_account_name = optional(string)
        restore_timestamp   = optional(string)
        master_username     = optional(string)
        master_password     = optional(string)
      }))
      imports = optional(object({
        account_name  = optional(string)
        database_name = optional(string)
      }))
    })
  })

  validation {
    condition     = contains(["3.2", "3.6", "4.0", "4.2"], var.instance.spec.version_config.api_version)
    error_message = "MongoDB API version must be one of: 3.2, 3.6, 4.0, 4.2."
  }

  validation {
    condition     = contains(["eventual", "session", "bounded_staleness", "strong", "consistent_prefix"], var.instance.spec.version_config.consistency_level)
    error_message = "Consistency level must be one of: eventual, session, bounded_staleness, strong, consistent_prefix."
  }

  validation {
    condition     = contains(["provisioned", "serverless"], var.instance.spec.sizing.throughput_mode)
    error_message = "Throughput mode must be either 'provisioned' or 'serverless'."
  }

  validation {
    condition     = var.instance.spec.sizing.max_throughput >= 400 && var.instance.spec.sizing.max_throughput <= 1000000
    error_message = "Maximum throughput must be between 400 and 1,000,000 RU/s."
  }

  validation {
    condition     = var.instance.spec.version_config.port >= 1024 && var.instance.spec.version_config.port <= 65535
    error_message = "Port must be between 1024 and 65535."
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
        tenant_id       = string
        client_id       = string
        client_secret   = string
      })
    })
    network_details = object({
      attributes = object({
        resource_group_id         = string
        resource_group_name       = string
        vnet_id                   = string
        vnet_name                 = string
        vnet_cidr_block           = string
        region                    = string
        availability_zones        = list(string)
        nat_gateway_ids           = list(string)
        nat_gateway_public_ip_ids = list(string)
        public_subnet_ids         = list(string)
        private_subnet_ids        = list(string)
        public_subnet_cidrs       = list(string)
        private_subnet_cidrs      = list(string)
        default_security_group_id = string
      })
    })
  })
}