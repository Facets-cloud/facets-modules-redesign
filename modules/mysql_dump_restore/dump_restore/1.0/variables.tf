variable "instance" {
  type = object({
    spec = object({
      source = object({
        host           = string
        port           = optional(number, 3306)
        admin_user     = string
        admin_password = string
      })
      target = object({
        host           = string
        port           = optional(number, 3306)
        admin_user     = string
        admin_password = string
      })
      databases   = optional(map(any), {})
      image       = optional(string, "mysql:8.4")
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
