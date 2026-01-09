variable "instance" {
  description = "Facets instance configuration"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      size = string
      advanced = optional(object({
        clustering_mode      = optional(string)
        enable_password_auth = optional(bool)
      }))
    })
    metadata = optional(object({
      tags = optional(map(string))
    }))
  })

  validation {
    condition     = contains(["small", "medium", "large", "xlarge"], var.instance.spec.size)
    error_message = "Size must be one of: small, medium, large, xlarge"
  }

  validation {
    condition = var.instance.spec.advanced == null || (
      var.instance.spec.advanced.clustering_mode == null ||
      contains(["standard", "legacy_compatible"], var.instance.spec.advanced.clustering_mode)
    )
    error_message = "Clustering mode must be one of: standard, legacy_compatible"
  }
}

variable "instance_name" {
  description = "Name of the Redis instance"
  type        = string
}

variable "environment" {
  description = "Facets environment configuration"
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = map(string)
  })
}

variable "inputs" {
  description = "Input dependencies from other Facets modules"
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
        resource_group_name          = string
        resource_group_id            = string
        vnet_id                      = string
        vnet_name                    = string
        region                       = string
        private_subnet_ids           = list(string)
        database_general_subnet_id   = optional(string)
        database_general_subnet_name = optional(string)
      })
    })
  })
}
