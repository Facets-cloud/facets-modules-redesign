variable "instance" {
  description = "Kubernetes Secret instance configuration"
  type = object({
    kind    = optional(string)
    flavor  = optional(string)
    version = optional(string)
    spec = optional(object({
      data = optional(map(object({
        key   = string
        value = string
      })), {})
    }), {})
    advanced = optional(object({
      k8s = optional(map(any), {})
    }), {})
  })
  default = {}
}

variable "instance_name" {
  type    = string
  default = "test_instance"
}


variable "environment" {
  description = "Environment configuration"
  type = object({
    namespace   = string
    name        = optional(string)
    unique_name = optional(string)
    cloud_tags  = optional(map(string), {})
  })
  default = {
    namespace = "default"
  }
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
