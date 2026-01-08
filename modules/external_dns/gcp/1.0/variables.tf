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
  description = "The external DNS resource instance configuration"
  type = object({
    kind     = optional(string)
    flavor   = optional(string)
    version  = optional(string)
    disabled = optional(bool, false)
    spec = optional(object({
      domain_filters    = optional(list(string), [])
      zone_visibility   = optional(string, "")
      batch_change_size = optional(number, 1000)
    }), {})
    advanced = optional(object({
      externaldns = optional(object({
        version         = optional(string, "6.28.5")
        cleanup_on_fail = optional(bool, true)
        wait            = optional(bool, false)
        atomic          = optional(bool, false)
        timeout         = optional(number, 300)
        recreate_pods   = optional(bool, false)
        values          = optional(map(any), {})
      }), {})
    }), {})
  })
}

variable "inputs" {
  description = "Input dependencies from other modules"
  type = object({
    kubernetes_details = object({
      attributes = object({
        cluster_name     = string
        cluster_endpoint = optional(string)
        cloud_provider   = optional(string)
        project_id       = optional(string) # Comes from GKE cluster
        region           = optional(string) # Comes from GKE cluster
      })
      interfaces = optional(any)
    })
    cloud_account = object({
      attributes = object({
        project_id  = string # GCP project ID
        project     = optional(string) # Backward compatibility
        credentials = optional(string) # Service account JSON
        region      = optional(string)
      })
    })
    kubernetes_node_pool_details = optional(object({
      attributes = optional(object({
        node_selector = optional(map(string), {})
        taints        = optional(list(any), [])
      }), {})
    }), null)
  })
}
