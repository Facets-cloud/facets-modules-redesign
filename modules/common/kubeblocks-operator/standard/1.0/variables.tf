variable "instance" {
  description = "Installs and configures KubeBlocks operator for managing databases on Kubernetes"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version = string
      feature_gates = optional(object({
        in_place_pod_vertical_scaling = optional(bool)
      }))
      high_availability = optional(object({
        replicas   = optional(number, 1)
        enable_pdb = optional(bool, false)
      }), {
        replicas   = 1
        enable_pdb = false
      })
      resources = optional(object({
        cpu_limit      = optional(string)
        memory_limit   = optional(string)
        cpu_request    = optional(string)
        memory_request = optional(string)
      }))
      database_addons = optional(object({
        postgresql = optional(bool)
        mysql      = optional(bool)
        mongodb    = optional(bool)
        redis      = optional(bool)
        kafka      = optional(bool)
      }))
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
      attributes = optional(object({
        cluster_name   = optional(string)
        region         = optional(string)
        legacy_outputs = optional(any)
      }))
      interfaces = optional(object({
        kubernetes_host                   = optional(string)
        kubernetes_cluster_ca_certificate = optional(string)
        kubernetes_token                  = optional(string)
      }))
    }),
    kubeblocks_crd = object({
      attributes = optional(object({
        version    = optional(string)
        crds_count = optional(number)
        release_id = optional(string)
      }))
      interfaces = optional(object({}))
    })
    node_pool = optional(object({
      attributes = object({
        node_pool_name = string
        node_pool_id   = string

        # List of taint objects: { key, value, effect }
        taints = optional(list(object({
          key    = string
          value  = string
          effect = string
        })), [])

        # Node labels used as nodeSelector
        node_selector = optional(map(string), {})
      })
      interfaces = any
    }))
  })
}
