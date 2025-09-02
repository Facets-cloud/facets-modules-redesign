variable "instance" {
  description = "Deploys and manages MongoDB database instances on Kubernetes using Helm charts with secure defaults and high availability"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version_config = object({
        mongo_version = optional(string, "8.0")
        database_name = optional(string, "myapp")
        root_password = optional(string)
        namespace     = optional(string, "default")
      })
      sizing = object({
        replica_count  = optional(number, 1)
        storage_size   = optional(string, "20Gi")
        cpu_request    = optional(string, "500m")
        memory_request = optional(string, "1Gi")
        cpu_limit      = optional(string, "1000m")
        memory_limit   = optional(string, "2Gi")
      })
      restore_config = optional(object({
        restore_from_backup = optional(bool, false)
        backup_source_pvc   = optional(string)
        init_js_configmap   = optional(string)
      }))
      imports = optional(object({
        statefulset_name = optional(string)
        service_name     = optional(string)
        secret_name      = optional(string)
        configmap_name   = optional(string)
        pvc_names        = optional(string)
      }))
    })
  })

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", var.instance.spec.version_config.database_name))
    error_message = "Database name must start with a letter and contain only letters, numbers, and underscores (max 63 characters)."
  }

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$", var.instance.spec.version_config.namespace)) || var.instance.spec.version_config.namespace == "default"
    error_message = "Namespace must be valid Kubernetes namespace name (lowercase alphanumeric and hyphens, max 63 characters)."
  }

  validation {
    condition     = contains(["6.0", "7.0", "8.0"], var.instance.spec.version_config.mongo_version)
    error_message = "MongoDB version must be one of: 6.0, 7.0, 8.0."
  }

  validation {
    condition     = var.instance.spec.sizing.replica_count >= 1 && var.instance.spec.sizing.replica_count <= 7
    error_message = "Replica count must be between 1 and 7."
  }

  validation {
    condition     = can(regex("^[0-9]+[KMGT]i$", var.instance.spec.sizing.storage_size))
    error_message = "Storage size must be in Kubernetes format (e.g., 20Gi, 100Gi)."
  }

  validation {
    condition     = var.instance.spec.version_config.root_password == null || try(length(var.instance.spec.version_config.root_password) >= 8, false)
    error_message = "Root password must be at least 8 characters long when specified."
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
    cloud_tags  = map(string)
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
