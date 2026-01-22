variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      receivers = map(object({
        type = string
        slack_config = optional(object({
          api_url_secret = string
          channel        = string
          title          = optional(string, "{{ .GroupLabels.alertname }}")
          text           = optional(string, "{{ range .Alerts }}{{ .Annotations.summary }}\\n{{ end }}")
        }))
        pagerduty_config = optional(object({
          service_key_secret = string
          severity           = optional(string, "critical")
        }))
        email_config = optional(object({
          to          = string
          from        = string
          smarthost   = string
          auth_secret = string
        }))
        webhook_config = optional(object({
          url         = string
          http_method = optional(string, "POST")
        }))
      }))

      routes = map(object({
        receiver        = string
        matchers        = map(string)
        continue        = optional(bool, false)
        group_by        = optional(list(string), ["alertname"])
        group_wait      = optional(string, "30s")
        group_interval  = optional(string, "5m")
        repeat_interval = optional(string, "4h")
      }))
    })
  })
  description = "Module instance configuration"
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
        alertmanager_url   = optional(string)
        prometheus_release = optional(string)
        namespace          = optional(string)
      })
      interfaces = optional(object({}), {})
    })
  })
  description = "Input dependencies from other modules"
}
