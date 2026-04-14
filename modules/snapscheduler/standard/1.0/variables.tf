variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      namespace        = optional(string)
      create_namespace = optional(bool)
      wait             = optional(bool)
      atomic           = optional(bool)
      timeout          = optional(number)
      recreate_pods    = optional(bool)
      resources = optional(object({
        cpu_request    = optional(string)
        cpu_limit      = optional(string)
        memory_request = optional(string)
        memory_limit   = optional(string)
      }))
      helm_values = optional(any)
    })
  })
}

variable "instance_name" {
  description = "Unique architectural name from the blueprint"
  type        = string
}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    namespace   = optional(string)
    cloud_tags  = optional(map(string), {})
  })
  description = "Environment context including name and cloud tags"
}

variable "inputs" {
  type = object({
    kubernetes_cluster = object({
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
    node_pool = object({
      attributes = object({
        node_pool_name  = optional(string)
        node_class_name = optional(string)
        node_selector   = optional(map(string), {})
        taints = optional(list(object({
          key    = string
          value  = string
          effect = string
        })), [])
      })
      interfaces = optional(any)
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
