variable "instance" {
  description = "MongoDB replica set deployed using MongoDB Community Operator on Kubernetes"
  type = object({
    kind    = string
    flavor  = string
    version = string
    metadata = optional(object({
      namespace = optional(string, "default")
    }), {})
    spec = object({
      mongodb_version = string
      replica_count   = number
      resources = optional(object({
        cpu    = optional(string, "1")
        memory = optional(string, "2Gi")
      }), {})
      storage_size    = optional(string, "10Gi")
      storage_class   = optional(string, "")
      max_connections = optional(number, 65536)
    })
  })

  validation {
    condition     = contains(["8.0.15", "7.0.15", "6.0.19", "5.0.30"], var.instance.spec.mongodb_version)
    error_message = "MongoDB version must be one of: 8.0.15, 7.0.15, 6.0.19, 5.0.30"
  }

  validation {
    condition     = var.instance.spec.replica_count >= 1 && var.instance.spec.replica_count <= 7
    error_message = "Replica count must be between 1 and 7"
  }
}

variable "instance_name" {
  description = "The architectural name for the resource as added in the Facets blueprint designer."
  type        = string
}

variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name        = string
    unique_name = string
  })
}

variable "inputs" {
  description = "A map of inputs requested by the module developer."
  type = object({
    kubernetes_cluster = object({
      attributes = any
      interfaces = any
    })
    node_pool = object({
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
    })
    mongodb_operator = object({
      attributes = object({
        namespace     = string
        release_name  = string
        chart_version = string
        operator_name = string
      })
      interfaces = any
    })
  })
}
