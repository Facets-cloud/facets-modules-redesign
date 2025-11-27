# PostgreSQL Cluster Module Variables
# KubeBlocks v0.9.5 - API v1alpha1

variable "instance_name" {
  description = "Instance name from Facets"
  type        = string
}
variable "namespace_override" {
  description = "Optional: Specify a custom namespace for the cluster. If not set, uses environment.namespace."
  type        = string
  default     = ""
}
variable "environment" {
  description = "Environment context from Facets"
  type = object({
    cloud_tags = map(string)
    namespace  = string
  })
}

variable "instance" {
  description = "PostgreSQL cluster instance configuration"
  type = object({
    spec = object({
      cluster_name       = string
      termination_policy = string
      postgres_version   = string
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
        storage_class = string
      })

      high_availability = optional(object({
        enable_pod_anti_affinity = optional(bool)
        anti_affinity_type       = optional(string)
        create_read_service      = optional(bool)
      }))

      backup = optional(object({
        enabled                   = optional(bool)
        create_backup_repo        = optional(bool)
        backup_repo_name          = optional(string)
        backup_repo_storage_size  = optional(string)
        backup_repo_storage_class = optional(string)
        enable_schedule           = optional(bool)
        schedule_cron             = optional(string)
        retention_period          = optional(string)
        backup_method             = optional(string)
      }))
      restore = optional(object({
        enabled          = optional(bool)
        backup_name      = optional(string)
        backup_namespace = optional(string)
        pitr_enabled     = optional(bool)
        pitr_timestamp   = optional(string)
      }))
    })
  })
}

variable "inputs" {
  description = "Input dependencies from other modules"
  type = object({
    kubeblocks_operator = object({
      output_attributes = optional(object({
        namespace     = optional(string)
        version       = optional(string)
        chart_version = optional(string)
      }))
      output_interfaces = optional(object({
        output = optional(object({
          release_id    = optional(string)
          dependency_id = optional(string)
          ready         = optional(string)
        }))
      }))
    })
    kubernetes_cluster = object({
      output_attributes = optional(object({
        cluster_name = optional(string)
        region       = optional(string)
      }))
    })
  })
}
