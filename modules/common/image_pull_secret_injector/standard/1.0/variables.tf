variable "instance" {
  description = "image_pull_secret_injector"
  type = object({
    kind    = string
    flavor  = string
    version = string
    metadata = optional(object({
      namespace = optional(string)
    }), {})
    spec = optional(object({
      size = optional(object({
        cpu_limit    = optional(string)
        memory_limit = optional(string)
      }), {})
      values = optional(any, {})
      image_pull_secret_injector = optional(object({
        version          = optional(string)
        cleanup_on_fail  = optional(bool)
        create_namespace = optional(bool)
        wait             = optional(bool)
        atomic           = optional(bool)
        timeout          = optional(number)
        recreate_pods    = optional(bool)
      }), {})
    }), {})
  })
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
  description = "Input dependencies for the image pull secret injector module."
  type = object({
    kubernetes_details = object({
      attributes = optional(object({
        cloud_provider   = optional(string)
        cluster_id       = optional(string)
        cluster_name     = optional(string)
        cluster_location = optional(string)
        cluster_endpoint = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
    artifactories = object({
      attributes = optional(object({
        registry_secrets_list = optional(list(object({
          name = optional(string)
        })), [])
        registry_secret_objects = optional(any, {})
      }), {})
      interfaces = optional(object({}), {})
    })
    kubernetes_node_pool_details = optional(object({
      attributes = optional(object({
        node_class_name = optional(string)
        node_pool_name  = optional(string)
        taints = optional(list(object({
          key    = string
          value  = string
          effect = string
        })), [])
        node_selector = optional(map(string), {})
      }), {})
      interfaces = optional(object({}), {})
    }))
  })
}
