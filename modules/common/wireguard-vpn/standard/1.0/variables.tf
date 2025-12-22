variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      namespace           = optional(string, "")
      enable_ip_forward   = optional(bool, true)
      mtu                 = optional(string, "1500")
      service_annotations = optional(map(string), {})
    })
  })

  validation {
    condition     = var.instance.spec.namespace == "" || can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.instance.spec.namespace))
    error_message = "Namespace must be empty or a valid Kubernetes namespace name (lowercase alphanumeric characters or '-', must start and end with an alphanumeric character)."
  }

  validation {
    condition     = can(regex("^[0-9]+$", var.instance.spec.mtu))
    error_message = "MTU must be a numeric string value."
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
    wireguard = object({
      attributes = optional(object({
        release_name = optional(string)
        namespace    = optional(string)
        chart        = optional(string)
        version      = optional(string)
        status       = optional(string)
      }))
      interfaces = optional(any)
    })
  })
}
