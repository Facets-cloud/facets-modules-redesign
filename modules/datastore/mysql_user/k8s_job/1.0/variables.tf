variable "instance" {
  description = "MySQL user and databases to provision on an existing MySQL instance"
  type = object({
    kind    = optional(string)
    flavor  = optional(string)
    version = optional(string)
    spec = object({
      user = object({
        name        = string
        auth_plugin = optional(string, "mysql_native_password")
        host        = optional(string, "%")
      })
      databases = optional(list(string), [])
      grants = optional(list(object({
        database   = string
        privileges = optional(string, "ALL PRIVILEGES")
      })), [])
      job = optional(object({
        namespace = optional(string, "default")
        image     = optional(string, "mysql:8.4")
      }), {})
    })
  })
}

variable "instance_name" {
  description = "Name of the resource instance"
  type        = string
}

variable "environment" {
  description = "Environment details injected by the platform"
  type = object({
    name                = string
    unique_name         = string
    cloud_tags          = optional(map(string), {})
    default_tolerations = optional(list(any), [])
  })
}

variable "inputs" {
  description = "Module dependencies"
  type = object({
    kubernetes_cluster = object({
      attributes = optional(any, {})
      interfaces = optional(any, {})
    })
    mysql = object({
      attributes = optional(any, {})
      interfaces = optional(object({
        writer = optional(object({
          host     = optional(string)
          port     = optional(number)
          username = optional(string)
          password = optional(string)
          database = optional(string)
        }), {})
      }), {})
    })
  })
}
