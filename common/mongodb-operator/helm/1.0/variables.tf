variable "instance" {
  description = "MongoDB Kubernetes Operator deployment configuration"
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
      helm_values = map(any)
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
  description = "The architectural name for the MongoDB Operator resource"
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
      attributes = map(any)
      interfaces = map(any)
    })
    node_pool = optional(object({
      attributes = object({
        node_selector = map(string)
        taints = map(object({
          key    = string
          value  = string
          effect = string
        }))
      })
      interfaces = map(any)
    }))
  })
}
