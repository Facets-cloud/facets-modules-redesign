variable "instance" {
  description = "Managed PostgreSQL database on Vultr with SSL/TLS and trusted-IP allow-listing"
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
      network_access = optional(object({
        trusted_ips = optional(list(string), [])
      }), {})
    })
  })

  validation {
    condition     = contains(["13", "14", "15", "16", "17"], var.instance.spec.version_config.version)
    error_message = "PostgreSQL version must be one of: 13, 14, 15, 16, 17."
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
  })
}
