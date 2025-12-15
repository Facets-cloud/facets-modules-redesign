# MinIO Object Storage Module Variables
# KubeBlocks v1.0 - API v1

variable "instance_name" {
  description = "Instance name from Facets"
  type        = string
}

variable "environment" {
  description = "Environment context from Facets"
  type = object({
    cloud_tags = map(string)
    namespace  = string
  })
}

variable "instance" {
  description = "MinIO cluster instance configuration"
  type = object({
    spec = object({
      namespace_override = optional(string)
      termination_policy = string
      minio_version      = string
      mode               = string
      replicas           = optional(number)
      volumes_per_server = number

      resources = object({
        cpu_request    = string
        cpu_limit      = string
        memory_request = string
        memory_limit   = string
      })

      storage = object({
        size          = string
        storage_class = string
      })

      buckets = optional(string)
    })
  })

  validation {
    condition = contains([
      "standalone",
      "distributed"
    ], var.instance.spec.mode)
    error_message = "Mode must be either 'standalone' or 'distributed'."
  }

  validation {
    condition = (
      var.instance.spec.mode == "standalone" ||
      (var.instance.spec.mode == "distributed" && lookup(var.instance.spec, "replicas", 4) >= 4)
    )
    error_message = "Distributed mode requires minimum 4 replicas for high availability."
  }

  validation {
    condition     = var.instance.spec.volumes_per_server >= 1 && var.instance.spec.volumes_per_server <= 16
    error_message = "Volumes per server must be between 1 and 16."
  }
}

variable "inputs" {
  description = "Input dependencies from other modules"
  type = object({
    kubeblocks_operator = object({
      attributes = optional(object({
        namespace     = optional(string)
        version       = optional(string)
        chart_version = optional(string)
      }))
      interfaces = optional(object({
        output = optional(object({
          release_id    = optional(string)
          dependency_id = optional(string)
          ready         = optional(string)
        }))
      }))
    })
    kubernetes_cluster = object({
      attributes = optional(object({
        cluster_name = optional(string)
        region       = optional(string)
      }))
    })
    node_pool = optional(object({
      attributes = object({
        node_pool_name = string
        node_pool_id   = string

        taints = optional(list(object({
          key    = string
          value  = string
          effect = string
        })), [])

        node_selector = optional(map(string), {})
      })
      interfaces = any
    }))
  })
}
