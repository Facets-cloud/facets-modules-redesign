variable "instance_name" {
  description = "The architectural name for the resource as added in the Facets blueprint designer."
  type        = string
}

variable "environment" {
  description = "Environment configuration."
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = map(string)
  })
}

variable "inputs" {
  description = "Input references from other modules."
  type = object({
    cloud_account = object({
      attributes = optional(object({
        credentials = optional(string)
        project_id  = optional(string)
        project     = optional(string)
        region      = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
    network_details = object({
      attributes = any
      interfaces = optional(object({}), {})
    })
  })
}

variable "instance" {
  description = "Compute Engine module configuration."
  type        = any
}
