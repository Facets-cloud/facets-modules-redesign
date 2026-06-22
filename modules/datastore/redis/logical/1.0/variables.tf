variable "instance" {
  description = "Logical Redis datastore hosted on an existing/shared instance — re-exposes an existing Redis datastore's outputs without provisioning any resource"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      # Resolved full outputs of the selected source @facets/redis datastore.
      source = object({
        attributes = optional(object({}), {})
        interfaces = optional(object({
          cluster = optional(object({
            endpoint          = optional(string)
            connection_string = optional(string)
            auth_token        = optional(string)
            port              = optional(string)
            secrets           = optional(list(string), [])
          }), {})
        }), {})
      })
      # Logical Redis DB index to target on the shared instance.
      db_index = optional(number, 0)
    })
  })

  validation {
    condition     = lookup(var.instance.spec, "db_index", 0) >= 0 && lookup(var.instance.spec, "db_index", 0) <= 15
    error_message = "db_index must be between 0 and 15"
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
  description = "A map of inputs requested by the module developer. This reference flavour requires no inputs."
  type        = object({})
  default     = {}
}
