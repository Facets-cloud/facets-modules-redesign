variable "instance" {
  description = "Redis deployment on Kubernetes using Helm chart with developer-friendly configuration"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version_config = object({
        redis_version = string
        architecture  = string
      })
      sizing = object({
        memory_limit  = string
        cpu_limit     = string
        storage_size  = string
        replica_count = number
      })
      restore_config = optional(object({
        restore_from_backup = bool
        backup_source_path  = optional(string)
      }))
      imports = optional(object({
        helm_release_name = optional(string)
        secret_name       = optional(string)
        service_name      = optional(string)
      }))
    })
  })

  validation {
    condition     = contains(["6.2", "7.0", "7.2"], var.instance.spec.version_config.redis_version)
    error_message = "Redis version must be one of: 6.2, 7.0, 7.2."
  }

  validation {
    condition     = contains(["standalone", "replication"], var.instance.spec.version_config.architecture)
    error_message = "Architecture must be either 'standalone' or 'replication'."
  }

  validation {
    condition     = contains(["256Mi", "512Mi", "1Gi", "2Gi", "4Gi", "8Gi"], var.instance.spec.sizing.memory_limit)
    error_message = "Memory limit must be one of: 256Mi, 512Mi, 1Gi, 2Gi, 4Gi, 8Gi."
  }

  validation {
    condition     = contains(["100m", "250m", "500m", "1000m", "2000m"], var.instance.spec.sizing.cpu_limit)
    error_message = "CPU limit must be one of: 100m, 250m, 500m, 1000m, 2000m."
  }

  validation {
    condition     = contains(["1Gi", "5Gi", "10Gi", "20Gi", "50Gi", "100Gi"], var.instance.spec.sizing.storage_size)
    error_message = "Storage size must be one of: 1Gi, 5Gi, 10Gi, 20Gi, 50Gi, 100Gi."
  }

  validation {
    condition     = var.instance.spec.sizing.replica_count >= 0 && var.instance.spec.sizing.replica_count <= 5
    error_message = "Replica count must be between 0 and 5."
  }
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
  description = "A map of inputs requested by the module developer."
  type = object({
    kubernetes_cluster = object({
      cluster = object({
        auth = object({
          host                   = string
          token                  = string
          cluster_ca_certificate = string
        })
      })
    })
  })
}