variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      global_replication_group_id    = string
      primary_replication_group_id   = string
      secondary_replication_group_id = string
      engine_version                 = string
      port                           = string
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
    source_cache = object({
      attributes = optional(object({}), {})
      interfaces = optional(object({
        cluster = optional(object({
          auth_token        = optional(string)
          connection_string = optional(string)
          endpoint          = optional(string)
          port              = optional(string)
          secrets           = optional(list(string), [])
        }))
      }), {})
    })
    destination_cache = object({
      attributes = optional(object({}), {})
      interfaces = optional(object({
        cluster = optional(object({
          auth_token        = optional(string)
          connection_string = optional(string)
          endpoint          = optional(string)
          port              = optional(string)
          secrets           = optional(list(string), [])
        }))
      }), {})
    })
  })
}
