variable "instance" {
  description = "Managed PostgreSQL database on Linode (Akamai) with SSL/TLS and IP allow-listing"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version_config = object({
        version = string
      })
      sizing = object({
        type         = string
        cluster_size = number
      })
      network_access = optional(object({
        allow_list = optional(list(string), [])
      }), {})
    })
  })

  validation {
    condition     = contains(["13", "14", "15", "16"], var.instance.spec.version_config.version)
    error_message = "PostgreSQL version must be one of: 13, 14, 15, 16."
  }

  validation {
    condition     = contains([1, 3], var.instance.spec.sizing.cluster_size)
    error_message = "cluster_size must be 1 or 3."
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
    linode_cloud_account = object({
      attributes = object({
        token  = string
        region = string
      })
    })
  })
}
