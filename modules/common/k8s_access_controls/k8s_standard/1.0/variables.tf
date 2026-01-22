variable "instance" {
  description = "Resource instance configuration from blueprint"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      roles = optional(map(object({
        metadata = optional(object({
          namespace   = optional(string)
          annotations = optional(map(string), {})
          labels      = optional(map(string), {})
        }))
        rules = map(object({
          api_groups     = list(string)
          resources      = list(string)
          resource_names = optional(list(string))
          verbs          = list(string)
        }))
      })), {})
      cluster_roles = optional(map(object({
        metadata = optional(object({
          annotations = optional(map(string), {})
          labels      = optional(map(string), {})
        }))
        rules = map(object({
          api_groups        = optional(list(string))
          resources         = optional(list(string))
          resource_names    = optional(list(string))
          non_resource_urls = optional(list(string))
          verbs             = list(string)
        }))
      })), {})
    })
  })
}

variable "instance_name" {
  description = "Unique architectural name from blueprint"
  type        = string
}

variable "environment" {
  description = "Environment context"
  type = object({
    name        = string
    unique_name = optional(string)
    namespace   = optional(string, "default")
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  description = "Input references from other modules"
  type = object({
    kubernetes_details = object({
      attributes = any
    })
  })
}
