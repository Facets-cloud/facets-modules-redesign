variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      # Custom labels
      labels = optional(map(string), {})
      # Alert configurations
      alerts = optional(object({
        mongodb_down = optional(object({
          enabled      = optional(bool, true)
          severity     = optional(string, "critical")
          for_duration = optional(string, "1m")
        }), {})
        mongodb_high_connections = optional(object({
          enabled      = optional(bool, true)
          severity     = optional(string, "warning")
          threshold    = optional(number, 80)
          for_duration = optional(string, "5m")
        }), {})
        mongodb_high_memory = optional(object({
          enabled      = optional(bool, true)
          severity     = optional(string, "warning")
          threshold_gb = optional(number, 3)
          for_duration = optional(string, "5m")
        }), {})
        mongodb_replication_lag = optional(object({
          enabled           = optional(bool, true)
          severity          = optional(string, "warning")
          threshold_seconds = optional(number, 10)
          for_duration      = optional(string, "2m")
        }), {})
        mongodb_replica_unhealthy = optional(object({
          enabled      = optional(bool, true)
          severity     = optional(string, "critical")
          for_duration = optional(string, "1m")
        }), {})
        mongodb_high_queued_operations = optional(object({
          enabled      = optional(bool, true)
          severity     = optional(string, "warning")
          threshold    = optional(number, 100)
          for_duration = optional(string, "5m")
        }), {})
        mongodb_slow_queries = optional(object({
          enabled      = optional(bool, true)
          severity     = optional(string, "info")
          threshold_ms = optional(number, 100)
          for_duration = optional(string, "5m")
        }), {})
      }), {})
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
  })
}
