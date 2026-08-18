# ╔═══════════════════════════════════════════════════════════╗
# ║ AUTO-GENERATED from facets.yaml — DO NOT EDIT            ║
# ║                                                          ║
# ║ Any changes will be overwritten on next mutation command. ║
# ╚═══════════════════════════════════════════════════════════╝

variable "instance" {
  type = object({
    spec = object({
      clickhouse_version = optional(string)
      cluster_domain     = optional(string)
      cluster_name       = optional(string)
      namespace          = optional(string)
      replicas           = optional(number)
      resources = optional(object({
        cpu    = optional(string)
        memory = optional(string)
      }))
      settings_json = optional(string)
      shards        = optional(number)
      storage_class = optional(string)
      storage_size  = optional(string)
      users_json    = optional(string)
    })
  })
}

variable "instance_name" {
  type        = string
  description = "Resource name in the blueprint (architectural name, e.g. main-db, api)"
}

variable "environment" {
  type = object({
    name        = string # Environment name (e.g., dev, staging, prod)
    unique_name = string # Project + environment (globally unique, e.g., myapp-prod)
  })
  description = "Environment context. Use unique_name + instance_name for globally unique resource names."
}

variable "inputs" {
  type = object({
    clickhouse_keeper = object({
      attributes = optional(object({
        namespace    = optional(string)
        port         = optional(number)
        replicas     = optional(number)
        service_host = optional(string)
      }))
      interfaces = optional(object({}))
    })
    clickhouse_operator = object({
      attributes = optional(object({
        namespace    = optional(string)
        release_name = optional(string)
      }))
      interfaces = optional(object({}))
    })
    kubernetes_details = object({
      attributes = optional(object({
        cloud_provider   = optional(string)
        cluster_endpoint = optional(string)
        cluster_id       = optional(string)
        cluster_location = optional(string)
        cluster_name     = optional(string)
      }))
      interfaces = optional(object({
        kubernetes = optional(object({
          cluster_ca_certificate = optional(string)
          host                   = optional(string)
        }))
      }))
    })
    node_pool = object({
      attributes = optional(object({
        node_class_name = optional(string)
        node_pool_name  = optional(string)
        node_selector   = optional(object({}))
        taints = optional(list(object({
          effect = optional(string)
          key    = optional(string)
          value  = optional(string)
        })))
      }))
      interfaces = optional(object({}))
    })
  })
}
