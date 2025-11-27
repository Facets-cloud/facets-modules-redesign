variable "instance" {
  description = "Installs and configures KubeBlocks operator for managing databases on Kubernetes"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version   = string
      namespace = string
      feature_gates = optional(object({
        in_place_pod_vertical_scaling = optional(bool)
      }))
      resources = optional(object({
        cpu_limit      = optional(string)
        memory_limit   = optional(string)
        cpu_request    = optional(string)
        memory_request = optional(string)
      }))
      database_addons = optional(object({
        postgresql = optional(bool)
        mysql      = optional(bool)
        mongodb    = optional(bool)
        redis      = optional(bool)
        kafka      = optional(bool)
      }))
    })
  })

  validation {
    condition     = contains(["0.9.5", "0.9.4", "0.9.3"], var.instance.spec.version)
    error_message = "KubeBlocks version must be a supported version (0.9.3, 0.9.4, or 0.9.5)"
  }

  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.instance.spec.namespace))
    error_message = "Namespace must be a valid Kubernetes namespace name"
  }

}

variable "instance_name" {
  description = "The architectural name for the resource as added in the Facets blueprint designer."
  type        = string
}

variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = map(string)
  })
}

variable "inputs" {
  description = "A map of inputs requested by the module developer."
  type = object({
    kubernetes_cluster = object({
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
  })
}
