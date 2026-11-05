variable "instance" {
  description = "Service Connection Policy configuration"
  type = object({
    kind     = optional(string)
    flavor   = optional(string)
    version  = optional(string)
    disabled = optional(bool, false)
    spec = object({
      service_class    = optional(string, "gcp-memorystore")
      connection_limit = optional(number, 4)
      description      = optional(string, "Memorystore PSC service connection policy")
      labels           = optional(map(string), {})
    })
  })

  validation {
    condition     = var.instance.spec.connection_limit >= 1 && floor(var.instance.spec.connection_limit) == var.instance.spec.connection_limit
    error_message = "connection_limit must be a positive integer."
  }
}

variable "instance_name" {
  description = "Resource name in the Facets blueprint."
  type        = string
}

variable "environment" {
  description = "Environment context."
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  description = "Input references from other modules."
  type = object({
    cloud_account = object({
      attributes = optional(object({
        project_id  = optional(string, "")
        credentials = optional(string, "")
        region      = optional(string, "")
      }), {})
      interfaces = optional(object({}), {})
    })
    network = object({
      attributes = optional(object({
        project_id           = optional(string, "")
        region               = optional(string, "")
        vpc_self_link        = optional(string, "")
        vpc_name             = optional(string, "")
        private_subnet_ids   = optional(list(string), [])
        private_subnet_cidrs = optional(list(string), [])
      }), {})
      interfaces = optional(object({}), {})
    })
  })
}
