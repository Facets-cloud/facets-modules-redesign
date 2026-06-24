variable "instance" {
  description = "The full Facets resource instance object (kind, flavor, version, spec)"
  type        = any
}

variable "instance_name" {
  description = "Unique architectural name from the blueprint"
  type        = string
}

variable "environment" {
  description = "Facets environment object"
  type        = any
}

variable "inputs" {
  description = "Typed input dependencies from other Facets resources"
  type = object({
    kubernetes_details = object({
      attributes = any
    })
    cloud_account = object({
      attributes = object({
        project_id = string
      })
    })
    storage = object({
      attributes = object({
        bucket_name = string
      })
    })
    kubernetes_node_pool_details = optional(object({
      attributes = optional(object({
        taints        = optional(list(any), [])
        node_selector = optional(map(string), {})
      }), {})
      interfaces = optional(object({}), {})
    }))
  })
}
