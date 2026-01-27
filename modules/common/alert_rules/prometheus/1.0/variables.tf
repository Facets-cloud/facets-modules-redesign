variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      alert_groups = map(object({
        rules = map(object({
          expression    = string
          duration      = optional(string, "5m")
          severity      = optional(string, "warning")
          resource_type = optional(string)
          resource_name = optional(string)
          summary       = string
          description   = optional(string, "")
          disabled      = optional(bool, false)
          labels        = optional(map(string), {})
          annotations   = optional(map(string), {})
          notification_channels = optional(object({
            slack     = optional(bool, false)
            email     = optional(bool, false)
            pagerduty = optional(bool, false)
            webhook   = optional(bool, false)
            }), {
            slack     = false
            email     = false
            pagerduty = false
            webhook   = false
          })
        }))
      }))
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
  description = "Environment configuration"
}

variable "inputs" {
  type = object({
    kubernetes_cluster = object({
      attributes = object({
        cluster_endpoint = string
        cluster_name     = string
      })
      interfaces = optional(object({}), {})
    })

    prometheus = object({
      attributes = object({
        prometheus_url     = optional(string)
        prometheus_release = optional(string)
        namespace          = optional(string)
      })
      interfaces = optional(object({}), {})
    })
  })
  description = "Input dependencies from other modules"
}
