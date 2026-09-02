variable "instance" {
  type = object({
    spec = object({
      source = object({
        host                           = string
        port                           = optional(number, 27017)
        admin_user                     = string
        admin_password                 = string
        auth_database                  = optional(string, "admin")
        tls                            = optional(bool, true)
        tls_allow_invalid_certificates = optional(bool, true)
        replica_set                    = optional(string, "")
        extra_uri_options              = optional(string, "")
      })
      target = object({
        host                           = string
        port                           = optional(number, 27017)
        admin_user                     = string
        admin_password                 = string
        auth_database                  = optional(string, "admin")
        tls                            = optional(bool, false)
        tls_allow_invalid_certificates = optional(bool, false)
        replica_set                    = optional(string, "")
        extra_uri_options              = optional(string, "")
      })
      databases   = optional(map(any), {})
      image       = optional(string, "alpine/mongosh:latest")
      namespace   = optional(string, "default")
      options     = optional(any, {})
      slack       = optional(any, {})
      tolerations = optional(object({}), {})
    })
    advanced = optional(any, {})
  })
}

variable "instance_name" {
  type        = string
  description = "Resource name in the blueprint."
}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  type = object({
    kubernetes_details = object({
      attributes = optional(any)
      interfaces = optional(any)
    })
  })
}
