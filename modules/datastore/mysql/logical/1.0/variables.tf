variable "instance" {
  description = "Reference (passthrough) to an existing MySQL datastore — re-exposes another MySQL resource's outputs without provisioning any cloud resource."
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      # source resolves (via x-ui-output-type: @facets/mysql) to the FULL outputs
      # of the selected MySQL resource: its attributes + interfaces (reader/writer).
      source = object({
        attributes = optional(any, {})
        interfaces = optional(object({
          reader = optional(object({
            host              = optional(string)
            port              = optional(number)
            username          = optional(string)
            password          = optional(string)
            database          = optional(string)
            connection_string = optional(string)
            secrets           = optional(list(string), [])
          }), {})
          writer = optional(object({
            host              = optional(string)
            port              = optional(number)
            username          = optional(string)
            password          = optional(string)
            database          = optional(string)
            connection_string = optional(string)
            secrets           = optional(list(string), [])
          }), {})
        }), {})
      })
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
  description = "A map of inputs requested by the module developer. This passthrough module requires none."
  type        = object({})
  default     = {}
}
