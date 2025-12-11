# MongoDB Cluster Module Variables
# KubeBlocks v1.0.1 - API v1

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
  description = "MongoDB cluster instance configuration"
  type = object({
    spec = object({
      namespace_override = optional(string)
      termination_policy = string
      mongodb_version    = string
      mode               = string
      replicas           = optional(number)

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

      high_availability = optional(object({
        enable_pod_anti_affinity = optional(bool)
      }))

      backup = optional(object({
        enabled          = optional(bool)
        enable_schedule  = optional(bool)
        schedule_cron    = optional(string)
        retention_period = optional(string)
      }))

      restore = optional(object({
        enabled     = optional(bool)
        backup_name = optional(string)
      }))
    })
  })
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
        disk_size_gb   = number
        node_count     = number

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
