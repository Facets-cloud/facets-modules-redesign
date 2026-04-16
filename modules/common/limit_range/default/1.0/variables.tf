variable "instance" {
  description = "LimitRange instance configuration"
  type = object({
    kind    = optional(string)
    flavor  = optional(string)
    version = optional(string)
    spec = optional(object({
      cluster_wide       = optional(bool, true)
      exclude_namespaces = optional(list(string), ["kube-node-lease", "kube-public"])
      target_namespaces  = optional(list(string), [])
      limits = optional(object({
        type                    = optional(string, "Container")
        default                 = optional(map(string), {})
        default_request         = optional(map(string), {})
        min                     = optional(map(string), {})
        max                     = optional(map(string), {})
        max_limit_request_ratio = optional(map(string), {})
      }), {})
      namespace_overrides = optional(map(object({
        default                 = optional(map(string))
        default_request         = optional(map(string))
        min                     = optional(map(string))
        max                     = optional(map(string))
        max_limit_request_ratio = optional(map(string))
      })), {})
    }), {})
    advanced = optional(object({
      k8s = optional(map(any), {})
    }), {})
  })
}

variable "instance_name" {
  type    = string
  default = "limit-range"
}

variable "environment" {
  description = "Environment configuration"
  type = object({
    namespace   = string
    name        = optional(string)
    unique_name = optional(string)
    cloud_tags  = optional(map(string), {})
  })
  default = {
    namespace = "default"
  }
}

variable "inputs" {
  description = "Input references from other modules"
  type = object({
    kubernetes_details = object({
      attributes = optional(object({
        cloud_provider   = optional(string)
        cluster_id       = optional(string)
        cluster_name     = optional(string)
        cluster_location = optional(string)
        cluster_endpoint = optional(string)
      }))
      interfaces = optional(object({
        kubernetes = optional(object({
          cluster_ca_certificate = optional(string)
          host                   = optional(string)
        }))
      }))
    })
  })
}
