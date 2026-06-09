variable "instance" {
  description = "Creates and manages an additional node pool on a Vultr Kubernetes Engine (VKE) cluster"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      node_type  = string
      node_count = number
      autoscaler = optional(object({
        enabled = optional(bool, false)
        min     = optional(number, 1)
        max     = optional(number, 5)
      }), {})
      labels = optional(map(object({
        key   = string
        value = string
      })), {})
      taints = optional(map(object({
        value  = optional(string, "")
        effect = string
      })), {})
    })
  })

  validation {
    condition     = var.instance.spec.node_count >= 1
    error_message = "node_count must be at least 1."
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
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  description = "A map of inputs requested by the module developer."
  type = object({
    vultr_cloud_account = object({
      attributes = object({
        api_key = string
        region  = string
      })
    })
    kubernetes_cluster = object({
      attributes = object({
        cluster_id   = string
        cluster_name = optional(string)
        region       = optional(string)
      })
    })
  })
}
