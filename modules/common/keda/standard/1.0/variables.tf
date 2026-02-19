variable "instance" {
  description = "Facets instance object containing spec and metadata"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      chart_version = optional(string, "2.9.4")
      size = optional(object({
        cpu    = optional(string)
        memory = optional(string)
      }), {})
      custom_values = optional(map(any), {})
    })
  })
}

variable "instance_name" {
  description = "Unique architectural name from blueprint"
  type        = string
}

variable "environment" {
  description = "An object containing details about the environment"
  type = object({
    name        = string
    unique_name = optional(string)
    namespace   = optional(string)
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  description = "Input variables from dependencies"
  type = object({
    kubernetes_details = object({
      attributes = optional(object({
        cloud_provider   = optional(string)
        cluster_id       = optional(string)
        cluster_name     = optional(string)
        cluster_location = optional(string)
        cluster_endpoint = optional(string)
      }))
      interfaces = optional(object({}))
    })
    kubernetes_node_pool_details = object({
      attributes = optional(object({
        node_class_name = optional(string)
        node_pool_name  = optional(string)
        taints = optional(list(object({
          key    = string
          value  = string
          effect = string
        })), [])
        node_selector = optional(map(string), {})
      }))
      interfaces = optional(object({}))
    })
    prometheus_details = optional(object({
      attributes = optional(object({
        alertmanager_url = optional(string)
        helm_release_id  = optional(string)
        prometheus_url   = optional(string)
      }))
      interfaces = optional(object({}))
    }))
  })
}
