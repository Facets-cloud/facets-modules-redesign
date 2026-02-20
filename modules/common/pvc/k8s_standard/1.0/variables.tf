variable "instance" {
  description = "Instance configuration from facets.yaml spec"
  type = object({
    spec = object({
      size = object({
        volume = string
      })
      access_modes       = optional(list(string), ["ReadWriteOnce"])
      storage_class_name = optional(string)
    })
  })
}

variable "instance_name" {
  type = string
}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    namespace   = string
    cloud_tags  = map(string)
  })
}

variable "inputs" {
  type = object({
    kubernetes_details = object({
      attributes = optional(object({
        cloud_provider   = optional(string)
        cluster_id       = optional(string)
        cluster_name     = optional(string)
        cluster_location = optional(string)
        cluster_endpoint = optional(string)
      }), {})
      interfaces = optional(object({
        kubernetes = optional(object({
          cluster_ca_certificate = optional(string)
          host                   = optional(string)
        }))
      }), {})
    })
  })
}
