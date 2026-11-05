# Cassandra Cluster Module Variables
# k8ssandra-operator (chart 0.30.1)

variable "instance_name" {
  description = "Instance name from Facets"
  type        = string
}

variable "environment" {
  description = "Environment context from Facets"
  type = object({
    cloud_tags = map(string)
    namespace  = string
  })
}

variable "instance" {
  description = "Cassandra cluster instance configuration"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      namespace_override = optional(string, "")
      cassandra_version  = string
      mode               = string
      replicas           = optional(number)

      resources = object({
        cpu_request    = string
        cpu_limit      = string
        memory_request = string
        memory_limit   = string
      })

      storage = object({
        size          = string
        storage_class = optional(string, "")
      })

      high_availability = optional(object({
        soft_pod_anti_affinity = optional(bool, true)
        }), {
        soft_pod_anti_affinity = true
      })
    })
  })
}

variable "inputs" {
  description = "Input dependencies from other modules"
  type = object({
    k8ssandra_operator = object({
      attributes = optional(object({
        namespace     = optional(string)
        release_name  = optional(string)
        release_id    = optional(string)
        chart_version = optional(string)
        operator_name = optional(string)
        repository    = optional(string)
        chart_name    = optional(string)
        status        = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
    kubernetes_cluster = object({
      cluster_name = optional(string)
      region       = optional(string)
    })
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

        # Node labels used as nodeSelector (mapped to rack nodeAffinityLabels)
        node_selector = optional(map(string), {})
      })
      interfaces = optional(object({}), {})
    }))
  })
}
