variable "instance" {
  description = "PostgreSQL database deployed on Kubernetes using Helm chart with configurable storage and high availability options"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version_config = object({
        version       = optional(string, "16")
        database_name = optional(string, "postgres")
        username      = optional(string, "postgres")
      })
      sizing = object({
        architecture = optional(string, "standalone")
        primary_resources = object({
          cpu          = optional(string, "250m")
          memory       = optional(string, "256Mi")
          cpu_limit    = optional(string, "1000m")
          memory_limit = optional(string, "1Gi")
        })
        read_replica_count = optional(number, 0)
        storage = object({
          size          = string
          storage_class = optional(string, "")
        })
      })
      restore_config = optional(object({
        restore_from_backup = bool
        backup_source = optional(object({
          source_type = string
          source_path = string
        }))
        master_password = optional(string)
      }))
      imports = optional(object({
        helm_release_name    = optional(string)
        namespace            = optional(string)
        primary_service_name = optional(string)
        secret_name          = optional(string)
      }))
    })
  })

  validation {
    condition     = can(regex("^(13|14|15|16)$", var.instance.spec.version_config.version))
    error_message = "PostgreSQL version must be one of: 13, 14, 15, 16."
  }

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", var.instance.spec.version_config.database_name))
    error_message = "Database name must start with a letter and contain only alphanumeric characters and underscores, max 63 characters."
  }

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{0,62}$", var.instance.spec.version_config.username))
    error_message = "Username must start with a letter and contain only alphanumeric characters and underscores, max 63 characters."
  }

  validation {
    condition     = contains(["standalone", "replication"], var.instance.spec.sizing.architecture)
    error_message = "Architecture must be either 'standalone' or 'replication'."
  }

  validation {
    condition     = lookup(var.instance.spec.sizing, "read_replica_count", 0) >= 0 && lookup(var.instance.spec.sizing, "read_replica_count", 0) <= 5
    error_message = "Read replica count must be between 0 and 5."
  }

  validation {
    condition     = can(regex("^[0-9]+(Ki|Mi|Gi|Ti|Pi|Ei|k|M|G|T|P|E)$", var.instance.spec.sizing.storage.size))
    error_message = "Storage size must be a valid Kubernetes quantity (e.g., '8Gi', '500Mi')."
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
  })
}

variable "inputs" {
  description = "A map of inputs requested by the module developer."
  type = object({
    kubernetes_cluster = any
  })

  validation {
    condition     = var.inputs.kubernetes_cluster != null
    error_message = "Kubernetes cluster input is required."
  }
}