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
      attributes = object({
        cluster_endpoint       = string
        cluster_ca_certificate = string
        token                  = optional(string)
      })
    })
    kubernetes_node_pool_details = optional(object({
      node_selector = optional(map(string))
      taints = optional(map(object({
        key    = string
        value  = string
        effect = string
      })))
    }), {})
  })
  default = {
    kubernetes_details = {
      attributes = {
        cluster_endpoint       = ""
        cluster_ca_certificate = ""
        token                  = ""
      }
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