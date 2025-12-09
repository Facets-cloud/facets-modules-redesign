variable "instance" {
  description = "GCP Managed Service for Apache Kafka cluster with secure defaults and automatic scaling"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version_config = object({
        kafka_version = string
      })
      sizing = object({
        vcpu_count   = number
        memory_gb    = number
        disk_size_gb = number
      })

      # Optional Kafka Connect cluster configuration
      connect_cluster = optional(object({
        enabled    = optional(bool, false)
        vcpu_count = optional(number, 12)
        memory_gb  = optional(number, 20)
      }))

      imports = optional(object({
        cluster_id            = optional(string)
        network_attachment_id = optional(string)
      }), {})
    })
  })

  validation {
    condition     = contains(["3.4", "3.5", "3.6", "3.7"], var.instance.spec.version_config.kafka_version)
    error_message = "Kafka version must be one of: 3.4, 3.5, 3.6, 3.7"
  }

  validation {
    condition     = var.instance.spec.sizing.vcpu_count >= 3 && var.instance.spec.sizing.vcpu_count <= 48
    error_message = "vCPU count must be between 3 and 48"
  }

  validation {
    condition     = var.instance.spec.sizing.memory_gb >= 3 && var.instance.spec.sizing.memory_gb <= 48
    error_message = "Memory GB must be between 3 and 48"
  }

  validation {
    condition     = var.instance.spec.sizing.disk_size_gb >= 100 && var.instance.spec.sizing.disk_size_gb <= 10000
    error_message = "Disk size must be between 100 and 10000 GB"
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
    gcp_cloud_account = object({
      attributes = object({
        project_id = string
        region     = string
      })
    })
    vpc_network = object({
      attributes = object({
        vpc_id            = string
        private_subnet_id = string
      })
    })
  })
}
