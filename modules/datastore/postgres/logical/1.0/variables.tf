variable "instance" {
  description = "A logical database hosted on an existing/shared PostgreSQL instance — re-exposes its connection outputs (no resources created)"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      # Resolves to the selected postgres resource's FULL outputs
      # (interfaces + attributes) injected by the platform via x-ui-output-type.
      source = object({
        attributes = optional(any, {})
        interfaces = object({
          reader = object({
            host              = string
            port              = string
            username          = string
            password          = string
            connection_string = string
            secrets           = optional(list(string), [])
          })
          writer = object({
            host              = string
            port              = string
            username          = string
            password          = string
            connection_string = string
            secrets           = optional(list(string), [])
          })
        })
      })
      # Optional logical DB name to target on the shared host (override-only).
      database_name = optional(string)
    })
  })
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
  description = "A map of inputs requested by the module developer. This logical flavour provisions nothing and requires no inputs."
  type        = object({})
}
