# Redis Cluster Module Variables
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
  description = "Redis cluster instance configuration"
  type = object({
    spec = object({
      namespace_override = optional(string)
      termination_policy = string
      redis_version      = string
      mode               = string
      replicas           = optional(number)
      shards             = optional(number)

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
        backup_method    = optional(string)
      }))

      restore = optional(object({
        enabled     = optional(bool)
        backup_name = optional(string)
      }))
    })
  })

  validation {
    condition     = contains(["standalone", "replication", "redis-cluster"], var.instance.spec.mode)
    error_message = "Cluster mode must be one of: standalone, replication, redis-cluster"
  }

  validation {
    condition     = contains(["Delete", "DoNotTerminate", "WipeOut"], var.instance.spec.termination_policy)
    error_message = "Termination policy must be one of: Delete, DoNotTerminate, WipeOut"
  }

  validation {
    condition = (
      var.instance.spec.mode != "replication" ||
      (var.instance.spec.mode == "replication" &&
        lookup(var.instance.spec, "replicas", 2) >= 1 &&
      lookup(var.instance.spec, "replicas", 2) <= 5)
    )
    error_message = "For replication mode, replicas must be between 1 and 5"
  }

  validation {
    condition = (
      var.instance.spec.mode != "redis-cluster" ||
      (var.instance.spec.mode == "redis-cluster" &&
        lookup(var.instance.spec, "shards", 3) >= 3 &&
      lookup(var.instance.spec, "shards", 3) <= 10)
    )
    error_message = "For redis-cluster mode, shards must be between 3 and 10"
  }
}

variable "inputs" {
  description = "Input dependencies from other modules"
  type = object({
    kubeblocks_operator = object({
      output_attributes = optional(object({
        namespace     = optional(string)
        version       = optional(string)
        chart_version = optional(string)
      }))
      output_interfaces = optional(object({
        output = optional(object({
          release_id    = optional(string)
          dependency_id = optional(string)
          ready         = optional(string)
        }))
      }))
    })
    kubernetes_cluster = object({
      output_attributes = optional(object({
        cluster_name = optional(string)
        region       = optional(string)
      }))
    })
  })

  validation {
    condition     = var.inputs.kubeblocks_operator.output_interfaces != null
    error_message = "KubeBlocks operator output_interfaces must be provided"
  }
}
