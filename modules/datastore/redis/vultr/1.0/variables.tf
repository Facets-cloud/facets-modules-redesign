variable "instance" {
  description = "Managed Valkey (Redis-compatible) cache on Vultr with TLS and trusted-IP allow-listing"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version_config = object({
        version = string
      })
      sizing = object({
        plan = string
      })
      advanced_config = optional(object({
        eviction_policy = optional(string, "noeviction")
      }), {})
      network_access = optional(object({
        trusted_ips = optional(list(string), [])
      }), {})
    })
  })

  validation {
    condition     = contains(["8.1", "9.0"], var.instance.spec.version_config.version)
    error_message = "Valkey version must be one of: 8.1, 9.0."
  }

  validation {
    condition = contains([
      "noeviction", "allkeys-lru", "volatile-lru", "allkeys-random",
      "volatile-random", "volatile-ttl", "volatile-lfu", "allkeys-lfu"
    ], var.instance.spec.advanced_config.eviction_policy)
    error_message = "eviction_policy must be a valid Valkey eviction policy."
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
    vultr_cloud_account = object({
      attributes = object({
        api_key = string
        region  = string
      })
    })
    network = optional(object({
      attributes = object({
        vpc_id = string
      })
    }))
  })
}
