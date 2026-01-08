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

    # Advanced, rarely-changed settings (chart version, custom values, etc.)
    advanced = optional(object({
      externaldns = optional(object({
        # Helm chart behaviour
        version         = optional(string)
        cleanup_on_fail = optional(bool)
        wait            = optional(bool)
        atomic          = optional(bool)
        timeout         = optional(number)
        recreate_pods   = optional(bool)

        # Extra Helm values to merge into the generated ones
        values = optional(map(any))

        # Chart source overrides (for debugging or custom forks)
        chart_path       = optional(string)
        chart_repository = optional(string)

        # Image overrides (for debugging or custom images)
        image_registry   = optional(string)
        image_repository = optional(string)
        image_tag        = optional(string)

        # Priority class override
        priority_class_name = optional(string)
      }), {})
    }), {})
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
