# Standard variables for Facets modules

variable "instance" {
  description = "Instance configuration"
  type        = any
}

variable "instance_name" {
  description = "The architectural name for the resource"
  type        = string
}

variable "environment" {
  description = "An object containing details about the environment"
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = map(string)
  })
}

variable "inputs" {
  description = "A map of inputs requested by the module developer"
  type = object({
    cloud_account = object({
      attributes = object({
        aws_iam_role = string
        aws_region   = string
        external_id  = string
        session_name = string
      })
      interfaces = optional(object({}))
    })
  })
}
