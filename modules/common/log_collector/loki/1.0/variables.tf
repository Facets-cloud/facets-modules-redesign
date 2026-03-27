variable "instance" {
  type = object({
    spec = optional(object({
      namespace                  = optional(string)
      container_runtime          = optional(string)
      log_retention_days         = optional(number)
      enable_grafana_datasource  = optional(bool)
      grafana_datasource_namespace = optional(string)
      auth_enabled               = optional(bool)
      replication_factor         = optional(number)
      storage_config = optional(object({
        s3 = optional(object({
          bucket_name       = optional(string)
          region            = optional(string)
          access_key_id     = optional(string)
          secret_access_key = optional(string)
        }))
      }))
      loki_size = optional(object({
        ingester = optional(object({
          replicas = optional(number)
          resources = optional(object({
            requests = optional(object({
              cpu    = optional(string)
              memory = optional(string)
            }))
            limits = optional(object({
              cpu    = optional(string)
              memory = optional(string)
            }))
          }))
        }))
        querier = optional(object({
          replicas = optional(number)
          resources = optional(object({
            requests = optional(object({
              cpu    = optional(string)
              memory = optional(string)
            }))
            limits = optional(object({
              cpu    = optional(string)
              memory = optional(string)
            }))
          }))
        }))
        distributor = optional(object({
          replicas = optional(number)
          resources = optional(object({
            requests = optional(object({
              cpu    = optional(string)
              memory = optional(string)
            }))
            limits = optional(object({
              cpu    = optional(string)
              memory = optional(string)
            }))
          }))
        }))
      }))
      promtail_size = optional(object({
        resources = optional(object({
          requests = optional(object({
            cpu    = optional(string)
            memory = optional(string)
          }))
          limits = optional(object({
            cpu    = optional(string)
            memory = optional(string)
          }))
        }))
      }))
      loki     = optional(any)
      promtail = optional(any)
      minio    = optional(any)
    }))
  })

  validation {
    condition = (
      try(var.instance.spec.container_runtime, "cri") == null ||
      contains(["cri", "docker"], try(var.instance.spec.container_runtime, "cri"))
    )
    error_message = "spec.container_runtime must be one of: cri, docker."
  }
}

variable "instance_name" {
  type    = string
  default = "test_instance"
}

variable "environment" {
  type = any
  default = {
    namespace = "default"
  }
}

variable "inputs" {
  type = object({
    kubernetes_details = object({
      attributes = optional(object({
        cloud_provider   = optional(string)
        cluster_id       = optional(string)
        cluster_name     = optional(string)
        cluster_location = optional(string)
        cluster_endpoint = optional(string)
      }))
      interfaces = optional(object({
        kubernetes = optional(object({
          cluster_ca_certificate = optional(string)
          host                   = optional(string)
        }))
      }))
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
      }))
      interfaces = optional(object({}))
    }))
    prometheus_details = optional(object({
      attributes = optional(object({
        alertmanager_url = optional(string)
        helm_release_id  = optional(string)
        prometheus_url   = optional(string)
      }))
      interfaces = optional(object({}))
    }))
  })
}
