variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      source_registry_id = string
      destinations = list(object({
        region      = string
        registry_id = string
      }))
      repository_prefixes = optional(list(string), [])
      repository_filters  = optional(list(string), [])
      scan_on_push        = optional(bool, true)
      immutable_tags      = optional(bool, true)
    })
  })
}

variable "instance_name" { type = string }

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  type = object({
    cloud_account = object({
      attributes = optional(object({
        aws_iam_role = optional(string)
        aws_region   = optional(string)
        external_id  = optional(string)
        session_name = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
  })
}
