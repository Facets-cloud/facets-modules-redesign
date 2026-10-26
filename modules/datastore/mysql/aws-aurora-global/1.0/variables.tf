variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      global_cluster_identifier    = string
      source_cluster_identifier    = string
      secondary_cluster_identifier = string
      engine                       = string
      engine_version               = string
      database_name                = string
      port                         = number
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
    source_database = object({
      attributes = optional(object({}), {})
      interfaces = optional(object({
        reader = optional(object({
          connection_string = optional(string)
          database          = optional(string)
          host              = optional(string)
          password          = optional(string)
          port              = optional(number)
          secrets           = optional(list(string), [])
          username          = optional(string)
        }))
        writer = optional(object({
          connection_string = optional(string)
          database          = optional(string)
          host              = optional(string)
          password          = optional(string)
          port              = optional(number)
          secrets           = optional(list(string), [])
          username          = optional(string)
        }))
      }), {})
    })
    destination_database = object({
      attributes = optional(object({}), {})
      interfaces = optional(object({
        reader = optional(object({
          connection_string = optional(string)
          database          = optional(string)
          host              = optional(string)
          password          = optional(string)
          port              = optional(number)
          secrets           = optional(list(string), [])
          username          = optional(string)
        }))
        writer = optional(object({
          connection_string = optional(string)
          database          = optional(string)
          host              = optional(string)
          password          = optional(string)
          port              = optional(number)
          secrets           = optional(list(string), [])
          username          = optional(string)
        }))
      }), {})
    })
  })
}
