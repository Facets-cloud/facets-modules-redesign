variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      # Resource allocation for MongoDB exporter
      resources = optional(object({
        requests = optional(object({
          cpu    = optional(string, "100m")
          memory = optional(string, "128Mi")
        }), {})
        limits = optional(object({
          cpu    = optional(string, "200m")
          memory = optional(string, "256Mi")
        }), {})
      }), {})

      # Additional helm values for advanced customization
      additional_helm_values = optional(map(any), {})
    })
  })
}

variable "instance_name" {
  type        = string
  description = "Unique architectural name from blueprint"
}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    namespace   = string
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  type = object({
    kubernetes_cluster = object({
      attributes = object({
        cluster_endpoint = string
        cluster_name     = string
      })
    })
    mongo = object({
      interfaces = object({
        writer = object({
          host              = string
          port              = string
          name              = string
          username          = string
          password          = string
          connection_string = string
        })
      })
    })
    prometheus = object({
      attributes = object({
        namespace          = string
        prometheus_release = string
      })
    })
    node_pool = optional(object({
      attributes = object({
        node_pool_name = string
        node_pool_id   = string

        # List of taint objects: { key, value, effect }
        taints = optional(list(object({
          key    = string
          value  = string
          effect = string
        })), [])

        # Node labels used as nodeSelector
        node_selector = optional(map(string), {})
      })
      interfaces = any
    }))
  })
}
