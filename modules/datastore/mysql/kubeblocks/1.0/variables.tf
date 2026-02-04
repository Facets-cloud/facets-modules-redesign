# MySQL Cluster Module Variables
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
  description = "MySQL cluster instance configuration"
  type = object({
    spec = object({
      namespace_override = optional(string)
      mysql_version      = string
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
        storage_class = optional(string, "")
      })

      high_availability = optional(object({
        enable_pod_anti_affinity = optional(bool)
      }))

      backup = optional(object({
        enabled          = optional(bool)
        schedule_cron    = optional(string)
        retention_period = optional(string)
        backup_method    = optional(string)
      }))

      restore = optional(object({
        enabled     = optional(bool)
        backup_name = optional(string)
      }))
    })
  })

  validation {
    condition     = contains(["5.7.44", "8.0.39", "8.4.2"], var.instance.spec.mysql_version)
    error_message = "MySQL version must be one of: 5.7.44, 8.0.39, 8.4.2"
  }

  validation {
    condition     = contains(["standalone", "replication"], var.instance.spec.mode)
    error_message = "Cluster mode must be either 'standalone' or 'replication'"
  }

  validation {
    condition = (
      var.instance.spec.mode == "standalone" ||
      (var.instance.spec.mode == "replication" &&
        lookup(var.instance.spec, "replicas", 2) >= 1 &&
      lookup(var.instance.spec, "replicas", 2) <= 5)
    )
    error_message = "For replication mode, replicas must be between 1 and 5"
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
        release_id    = optional(string)
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
