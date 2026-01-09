variable "instance_name" {
  description = "The architectural name for the resource as added in the Facets blueprint designer."
  type        = string
  default     = "test_instance"
}

variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name        = optional(string)
    unique_name = optional(string)
    cloud_tags  = optional(map(string), {})
    namespace   = optional(string, "default")
  })
  default = {
    namespace = "default"
  }
}

variable "instance" {
  description = "Configuration for the external-dns Azure module"
  type = object({
    kind     = optional(string)
    flavor   = optional(string)
    version  = optional(string)
    disabled = optional(bool, false)
  })
  default = {}
}

variable "inputs" {
  description = "Input dependencies from other modules"
  type = object({
    kubernetes_details = object({
      attributes = object({
        cluster_name        = string
        cluster_endpoint    = optional(string)
        cloud_provider      = optional(string)
        resource_group_name = string           # Comes from AKS cluster (which gets it from network module)
        cluster_location    = optional(string) # Azure region
        network_details = optional(object({
          resource_group_name = optional(string)
          region              = optional(string)
        }), {})
      })
      interfaces = optional(any)
    })
    cloud_account = object({
      attributes = object({
        subscription_id = string
        tenant_id       = string
        client_id       = string
        client_secret   = string
      })
    })
    kubernetes_node_pool_details = optional(object({
      attributes = optional(object({
        node_selector = optional(map(string), {})
        taints        = optional(any, null)
      }), {})
    }), null)
  })
}
