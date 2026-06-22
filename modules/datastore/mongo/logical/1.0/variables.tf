variable "instance" {
  description = "Reference an existing MongoDB / DocumentDB datastore (passthrough, no resources)."
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      # Full outputs of the selected source mongo datastore, resolved by the
      # platform from the spec field's x-ui-output-type ('@facets/mongo').
      source = object({
        attributes = optional(object({}), {})
        interfaces = optional(object({
          writer = optional(object({
            host              = optional(string)
            port              = optional(string)
            username          = optional(string)
            password          = optional(string)
            connection_string = optional(string)
            name              = optional(string)
            secrets           = optional(list(string), [])
          }), {})
          reader = optional(object({
            host              = optional(string)
            port              = optional(string)
            username          = optional(string)
            password          = optional(string)
            connection_string = optional(string)
            name              = optional(string)
            secrets           = optional(list(string), [])
          }), {})
          cluster = optional(object({
            endpoint          = optional(string)
            username          = optional(string)
            password          = optional(string)
            connection_string = optional(string)
            secrets           = optional(list(string), [])
          }), {})
        }), {})
      })
      # Optional logical database to target in the re-exposed connection string.
      database_name = optional(string)
    })
  })
}

variable "instance_name" {
  description = "The architectural name of the resource as added in the blueprint."
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment-level metadata injected by the platform."
  type = object({
    name        = optional(string)
    unique_name = optional(string)
    namespace   = optional(string)
  })
  default = {}
}

variable "inputs" {
  description = "No dependency inputs — this flavour is a pure passthrough."
  type        = object({})
  default     = {}
}
