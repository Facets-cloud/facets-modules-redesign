variable "instance" {
  description = "Namespace instance configuration"
  type = object({
    kind    = optional(string)
    flavor  = optional(string)
    version = optional(string)
    spec = optional(object({
      name = optional(string)
    }), {})
  })
}

variable "instance_name" {
  type    = string
  default = "test_instance"
}

variable "environment" {
  description = "Environment configuration"
  type = object({
    name        = string
    namespace   = optional(string)
    unique_name = optional(string)
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  description = "Input references from other modules"
  type = object({
    kubernetes_details = object({
      attributes = optional(object({
        cloud_provider   = optional(string)
        cluster_id       = optional(string)
        cluster_name     = optional(string)
        cluster_location = optional(string)
        cluster_endpoint = optional(string)
      }))
      interfaces = optional(object({
        kubernetes = optional(object({
          cluster_ca_certificate = optional(string)
          host                   = optional(string)
        }))
      }))
    })
  })
}
