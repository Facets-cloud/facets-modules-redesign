variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      destination_region                 = string
      destination_availability_zone_name = optional(string, "")
      kms_key_id                         = optional(string, "")
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
    source_file_system = object({
      attributes = optional(object({
        file_system_id    = optional(string)
        security_group_id = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
    destination_file_system = object({
      attributes = optional(object({
        file_system_id    = optional(string)
        security_group_id = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
  })
}
