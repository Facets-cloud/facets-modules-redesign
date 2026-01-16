variable "instance_name" {
  description = "The architectural name for the resource as added in the Facets blueprint designer."
  type        = string
  default     = "test_instance"
}

variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name                = optional(string)
    unique_name         = optional(string)
    cloud_tags          = optional(map(string), {})
    namespace           = optional(string, "default")
    default_tolerations = optional(list(any), [])
  })
  default = {
    namespace = "default"
  }
}

variable "instance" {
  description = "Configuration for the external-dns GCP module"
  type = object({
    kind     = optional(string)
    flavor   = optional(string)
    version  = optional(string)
    disabled = optional(bool, false)
    spec = optional(object({
      zone_visibility   = optional(string, "public")
      batch_change_size = optional(number, 1000)
    }), {})
  })
  default = {}
}

variable "inputs" {
  description = "Input dependencies from other modules"
  type = object({
    kubernetes_details = object({
      attributes = object({
        cluster_name = string
        project_id   = optional(string) # Comes from GKE cluster
        region       = optional(string) # Comes from GKE cluster
      })
      interfaces = optional(any)
    })
    cloud_account = object({
      attributes = object({
        project_id  = string           # GCP project ID
        project     = optional(string) # Backward compatibility
        credentials = optional(string) # Service account JSON
        region      = optional(string)
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
