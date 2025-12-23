variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      namespace = optional(string, "")
      operator_resources = optional(object({
        requests = optional(object({
          cpu    = optional(string, "100m")
          memory = optional(string, "128Mi")
        }), {})
        limits = optional(object({
          cpu    = optional(string, "200m")
          memory = optional(string, "256Mi")
        }), {})
      }), {})
      values = optional(map(any), {})
    })
  })

  validation {
    condition = (
      var.instance.spec.namespace == "" ||
      can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.instance.spec.namespace))
    )
    error_message = "Namespace must be empty or a valid Kubernetes namespace name (lowercase alphanumeric characters or '-', must start and end with an alphanumeric character)."
  }

  validation {
    condition = (
      can(regex("^[0-9]+m$", var.instance.spec.operator_resources.requests.cpu)) ||
      can(regex("^[0-9]+(\\.[0-9]+)?$", var.instance.spec.operator_resources.requests.cpu))
    )
    error_message = "CPU request must be in format '100m' or '0.1' (cores)."
  }

  validation {
    condition = (
      can(regex("^[0-9]+(Mi|Gi)$", var.instance.spec.operator_resources.requests.memory))
    )
    error_message = "Memory request must be in format '128Mi' or '1Gi'."
  }

  validation {
    condition = (
      can(regex("^[0-9]+m$", var.instance.spec.operator_resources.limits.cpu)) ||
      can(regex("^[0-9]+(\\.[0-9]+)?$", var.instance.spec.operator_resources.limits.cpu))
    )
    error_message = "CPU limit must be in format '200m' or '0.2' (cores)."
  }

  validation {
    condition = (
      can(regex("^[0-9]+(Mi|Gi)$", var.instance.spec.operator_resources.limits.memory))
    )
    error_message = "Memory limit must be in format '256Mi' or '1Gi'."
  }
}

variable "instance_name" {
  type        = string
  description = "Unique architectural name from blueprint"

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.instance_name))
    error_message = "Instance name must be a valid Kubernetes resource name (lowercase alphanumeric characters or '-', must start and end with an alphanumeric character)."
  }
}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    cloud       = string
    cloud_tags  = optional(map(string), {})
    namespace   = string
  })
  description = "Environment metadata including name, cloud provider, and namespace"
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
    node_pool = object({
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
      interfaces = optional(any)
    })
  })
  description = "Input dependencies from other modules (kubernetes cluster and node pool)"

  validation {
    condition     = var.inputs.node_pool.attributes.node_pool_name != ""
    error_message = "Node pool name cannot be empty."
  }
}
