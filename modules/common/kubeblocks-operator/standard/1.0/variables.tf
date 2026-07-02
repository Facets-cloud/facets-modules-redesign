variable "instance" {
  description = "Installs and configures KubeBlocks operator for managing databases on Kubernetes"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version = string
      high_availability = optional(object({
        replicas   = optional(number, 1)
        enable_pdb = optional(bool, false)
        }), {
        replicas   = 1
        enable_pdb = false
      })
      resources = optional(object({
        cpu_limit      = optional(string, "1000m")
        memory_limit   = optional(string, "1Gi")
        cpu_request    = optional(string, "500m")
        memory_request = optional(string, "512Mi")
        }), {
        cpu_limit      = "1000m"
        memory_limit   = "1Gi"
        cpu_request    = "500m"
        memory_request = "512Mi"
      })
      database_addons = optional(object({
        postgresql = optional(bool, true)
        mysql      = optional(bool, true)
        mongodb    = optional(bool, true)
        redis      = optional(bool, true)
        kafka      = optional(bool, true)
      }), {})
    })
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
    cloud_tags  = map(string)
  })
}

variable "inputs" {
  description = "A map of inputs requested by the module developer."
  type = object({
    kubernetes_cluster = object({
      cluster_name = optional(string)
      region       = optional(string)
    }),
    node_pool = optional(object({
      attributes = object({
        node_pool_name = string
        node_pool_id   = optional(string)

        # List of taint objects: { key, value, effect }
        taints = optional(list(object({
          key    = string
          value  = string
          effect = string
        })), [])

        # Node labels used as nodeSelector
        node_selector = optional(map(string), {})
      })
      interfaces = optional(object({}), {})
    }))
  })
}
