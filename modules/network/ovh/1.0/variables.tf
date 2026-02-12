variable "instance" {
  description = "Creates private network infrastructure for OVH Managed Kubernetes clusters"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      region       = string
      network_cidr = string
      vlan_id      = number
    })
  })

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.instance.spec.network_cidr))
    error_message = "network_cidr must be a valid CIDR block (e.g., 10.0.0.0/16)."
  }

  validation {
    condition     = var.instance.spec.vlan_id >= 0 && var.instance.spec.vlan_id <= 4000
    error_message = "vlan_id must be between 0 and 4000."
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
    ovh_provider = object({
      attributes = object({
        endpoint           = string
        application_key    = string
        application_secret = string
        consumer_key       = string
        project_id         = string
      })
    })
  })
}
