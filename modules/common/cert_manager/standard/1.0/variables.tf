variable "instance" {
  type = any

  validation {
    condition     = contains(["Follow", "None"], var.instance.spec.cname_strategy)
    error_message = "cname_strategy must be either 'Follow' or 'None'."
  }

  validation {
    condition     = lookup(var.instance.spec, "use_gts", false) ? lookup(var.instance.spec, "gts_private_key", "") != "" : true
    error_message = "gts_private_key is required when use_gts is enabled."
  }
}

variable "instance_name" {
  type    = string
  default = "test_instance"
}

variable "environment" {
  type = any
  default = {
    namespace = "default"
  }
}

variable "inputs" {
  type = object({
    prometheus_details = optional(object({
      attributes = optional(any)
    }))
    kubernetes_details = object({
      attributes = object({
        cluster_endpoint = string
        cluster_name     = optional(string)
        cluster_id       = optional(string)
      })
      interfaces = optional(object({
        kubernetes = optional(object({
          host                   = string
          cluster_ca_certificate = string
        }))
      }))
    })
    kubernetes_node_pool_details = optional(object({
      node_selector = optional(map(string))
      taints = optional(map(object({
        key    = string
        value  = string
        effect = string
      })))
    }))
  })
}

variable "cc_metadata" {
  type    = any
  default = {}
}

variable "cluster" {
  type    = any
  default = {}
}
