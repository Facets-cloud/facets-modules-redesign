variable "instance" {
  description = "Strimzi Kafka Operator deployment configuration"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      namespace = string
      resources = object({
        cpu_request    = string
        cpu_limit      = string
        memory_request = string
        memory_limit   = string
      })
      helm_values = optional(map(any), {})
    })
  })
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.instance.spec.namespace)) || var.instance.spec.namespace == ""
    error_message = "Namespace must be a valid Kubernetes namespace name (lowercase alphanumeric and hyphens) or empty string."
  }

  validation {
    condition     = length(var.instance.spec.namespace) <= 63
    error_message = "Namespace must not exceed 63 characters."
  }
}

variable "instance_name" {
  description = "The architectural name for the Strimzi Operator resource"
  type        = string
}

variable "environment" {
  description = "Environment details"
  type = object({
    name        = string
    unique_name = string
  })
}

variable "inputs" {
  description = "Module dependencies"
  type = object({
    kubernetes_cluster = object({
      attributes = optional(object({
        cloud_provider   = optional(string)
        cluster_id       = optional(string)
        cluster_name     = optional(string)
        cluster_location = optional(string)
        cluster_endpoint = optional(string)
      }), {})
      interfaces = optional(object({
        kubernetes = optional(object({
          cluster_ca_certificate = optional(string)
          host                   = optional(string)
        }), {})
      }), {})
    })
    node_pool = optional(object({
      attributes = optional(object({
        node_pool_name  = optional(string)
        node_class_name = optional(string)
        node_selector   = optional(map(string), {})
        taints = optional(list(object({
          key    = optional(string)
          value  = optional(string)
          effect = optional(string)
        })), [])
      }), {})
      interfaces = optional(object({}), {})
    }))
  })
}
