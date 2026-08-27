variable "instance" {
  type = object({
    spec = object({
      include_all = bool
      artifactories = map(object({
        name = string
      }))
    })
  })
  default = {
    spec = {
      include_all   = false
      artifactories = {}
    }
  }
  description = "Instance configuration for the artifactories module"
}

variable "instance_name" {
  type        = string
  default     = ""
  description = "Unique architectural name for the resource"
}

variable "inputs" {
  type = object({
    kubernetes_details = object({
      cluster_endpoint       = string
      cluster_ca_certificate = string
      token                  = optional(string)
    })
    # facets.yaml declares this input optional: false, so the object is required.
    # node_selector and taints live under attributes -- this is the whole module
    # output, not its attributes map. Every other consumer (keda,
    # ack_acm_controller, gateway_api_crd, image_pull_secret_injector) reads
    # them there; this module read them at the top level, so the conversion
    # dropped attributes and left both null. Shape mirrors cert_manager and
    # gateway_api_crd, except attributes carries a {} default so it can never
    # arrive null.
    kubernetes_node_pool_details = object({
      attributes = optional(object({
        node_class_name = optional(string)
        node_pool_name  = optional(string)
        taints = optional(list(object({
          key    = string
          value  = string
          effect = string
        })), [])
        node_selector = optional(map(string), {})
      }), {})
      interfaces = optional(object({}), {})
    })
  })
  default = {
    kubernetes_details = {
      cluster_endpoint       = ""
      cluster_ca_certificate = ""
      token                  = ""
    }
    kubernetes_node_pool_details = {}
  }
  description = "Input dependencies from other modules"
}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    namespace   = string
    cloud_tags  = map(string)
  })
  default = {
    name        = ""
    unique_name = ""
    namespace   = "default"
    cloud_tags  = {}
  }
  description = "Environment-specific configuration"
}