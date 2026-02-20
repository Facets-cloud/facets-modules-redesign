variable "instance" {
  description = "Kafka cluster deployment configuration"
  type = object({
    spec = optional(object({
      version_config = optional(object({
        kafka_version  = optional(string)
        admin_username = optional(string)
      }), {})
      sizing = optional(object({
        replica_count = optional(number)
        storage_size  = optional(string)
        resources = optional(object({
          cpu    = optional(string)
          memory = optional(string)
        }), {})
      }), {})
      listeners = optional(object({
        plain_enabled = optional(bool)
        tls_enabled   = optional(bool)
      }), {})
      config = optional(object({
        offsets_topic_replication_factor         = optional(number)
        transaction_state_log_replication_factor = optional(number)
        transaction_state_log_min_isr            = optional(number)
        default_replication_factor               = optional(number)
        min_insync_replicas                      = optional(number)
      }), {})
    }), {})
  })
}

variable "instance_name" {
  description = "The architectural name for the Kafka cluster resource"
  type        = string
}

variable "environment" {
  description = "Environment details"
  type = object({
    name        = string
    unique_name = string
  })
}

variable "inputs" {
  description = "Module dependencies"
  type = object({
    kubernetes_cluster = object({
      attributes = optional(object({
        cloud_provider   = optional(string)
        cluster_id       = optional(string)
        cluster_name     = optional(string)
        cluster_location = optional(string)
        cluster_endpoint = optional(string)
      }), {})
      interfaces = optional(object({
        kubernetes = optional(object({
          cluster_ca_certificate = optional(string)
          host                   = optional(string)
        }), {})
      }), {})
    })
    strimzi_operator = object({
      attributes = optional(object({
        namespace     = optional(string)
        release_name  = optional(string)
        release_id    = optional(string)
        operator_name = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
    node_pool = optional(object({
      attributes = optional(object({
        node_class_name = optional(string)
        node_pool_name  = optional(string)
        taints = optional(list(object({
          key    = optional(string)
          value  = optional(string)
          effect = optional(string)
        })), [])
        node_selector = optional(map(string), {})
      }), {})
      interfaces = optional(object({}), {})
    }))
  })
}
