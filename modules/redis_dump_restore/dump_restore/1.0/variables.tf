variable "instance" {
  type = object({
    spec = object({
      source = object({
        host       = string
        port       = optional(number, 6379)
        auth_token = optional(string, "")
        tls        = optional(bool, false)
      })
      target = object({
        host       = string
        port       = optional(number, 6379)
        auth_token = optional(string, "")
        tls        = optional(bool, false)
      })
      datasets    = optional(map(any), {})
      image       = optional(string, "redis:7.2-alpine")
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
