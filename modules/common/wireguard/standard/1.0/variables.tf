variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      namespace        = optional(string)
      create_namespace = optional(bool, true)
      resources = optional(object({
        requests = optional(object({
          cpu    = optional(string, "100m")
          memory = optional(string, "256Mi")
        }), {})
        limits = optional(object({
          cpu    = optional(string, "100m")
          memory = optional(string, "256Mi")
        }), {})
      }), {})
      helm_config = optional(object({
        version = optional(string, "0.31.0")
        wait    = optional(bool, true)
        atomic  = optional(bool, true)
        timeout = optional(number, 600)
      }), {})
      values = optional(map(any), {})
    })
  })

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.instance.spec.namespace))
    error_message = "Namespace must be a valid Kubernetes namespace name (lowercase alphanumeric characters or '-', must start and end with an alphanumeric character)."
  }

  validation {
    condition     = var.instance.spec.helm_config.timeout >= 0
    error_message = "Timeout must be a non-negative number."
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
    cloud       = string
    cloud_tags  = optional(map(string), {})
    namespace   = string
  })
}

variable "inputs" {
  type = object({
    kubernetes_details = object({
      attributes = optional(object({
        cluster_name   = optional(string)
        region         = optional(string)
        legacy_outputs = optional(any)
      }))
      interfaces = optional(object({
        kubernetes_host                   = optional(string)
        kubernetes_cluster_ca_certificate = optional(string)
        kubernetes_token                  = optional(string)
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
