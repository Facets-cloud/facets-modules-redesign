variable "instance" {
  description = "Creates a Vultr Kubernetes Engine (VKE) cluster with a default node pool"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      k8s_version       = string
      high_availability = optional(bool, false)
      enable_firewall   = optional(bool, false)
      default_pool = object({
        node_type  = string
        node_count = number
        autoscaler = optional(object({
          enabled = optional(bool, false)
          min     = optional(number, 1)
          max     = optional(number, 5)
        }), {})
      })
    })
  })

  validation {
    condition     = can(regex("^v[0-9]+\\.[0-9]+\\.[0-9]+\\+[0-9]+$", var.instance.spec.k8s_version))
    error_message = "k8s_version must be a Vultr VKE version string like v1.35.0+1."
  }

  validation {
    condition     = var.instance.spec.default_pool.node_count >= 1
    error_message = "default_pool.node_count must be at least 1."
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
        vpc_id = optional(string)
        region = optional(string)
      })
    }))
  })
}
