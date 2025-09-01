variable "instance" {
  description = "Apache Kafka cluster deployment on Kubernetes using Helm"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version_config = object({
        version      = string
        cluster_size = number
      })
      sizing = object({
        storage_size       = number
        memory_limit       = string
        cpu_limit          = string
        enable_persistence = bool
      })
      restore_config = optional(object({
        restore_from_backup = bool
        backup_source       = optional(string)
      }))
      imports = optional(object({
        helm_release_name = optional(string)
      }))
    })
  })

  validation {
    condition     = contains(["2.8", "3.4", "3.6"], var.instance.spec.version_config.version)
    error_message = "Kafka version must be one of: 2.8, 3.4, 3.6"
  }

  validation {
    condition     = var.instance.spec.version_config.cluster_size >= 1 && var.instance.spec.version_config.cluster_size <= 10
    error_message = "Cluster size must be between 1 and 10"
  }

  validation {
    condition     = var.instance.spec.sizing.storage_size >= 10
    error_message = "Storage size must be at least 10 GB"
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