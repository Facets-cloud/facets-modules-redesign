variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      prometheus_namespace = string
      labels               = optional(map(string), {})
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

  validation {
    condition     = can(regex("^[0-9]+[smhd]$", var.instance.spec.alerts.mongodb_down.for_duration))
    error_message = "for_duration must be a valid duration (e.g., 1m, 5m, 1h)."
  }
}

variable "instance_name" {
  type        = string
  description = "Unique architectural name from blueprint"
}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
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
      attributes = object({
        service_name = string
        port         = string
      })
      interfaces = object({
        primary = object({
          host = string
          port = string
        })
      })
    })
  })
}
