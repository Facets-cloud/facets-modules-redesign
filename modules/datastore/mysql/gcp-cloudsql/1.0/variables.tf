variable "instance" {
  description = "Managed MySQL database using Google Cloud SQL with automated backups and high availability"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version_config = object({
        version       = string
        database_name = string
      })
      sizing = object({
        tier               = string
        disk_size          = number
        read_replica_count = number
      })
      restore_config = optional(object({
        restore_from_backup = bool
        source_instance_id  = optional(string)
        master_username     = optional(string)
        master_password     = optional(string)
      }))
      imports = optional(object({
        import_existing = optional(bool, false)
        instance_name   = optional(string)
        database_name   = optional(string)
        root_user       = optional(string)
        read_replica_0  = optional(string)
        read_replica_1  = optional(string)
        read_replica_2  = optional(string)
        master_password = optional(string)
      }))
    })
  })

  validation {
    condition     = contains(["5.7", "8.0", "8.4"], var.instance.spec.version_config.version)
    error_message = "MySQL version must be one of: 5.7, 8.0, 8.4"
  }

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.instance.spec.version_config.database_name))
    error_message = "Database name must start with a letter and contain only letters, numbers, and underscores"
  }

  validation {
    condition = contains([
      "db-f1-micro", "db-g1-small", "db-n1-standard-1",
      "db-n1-standard-2", "db-n1-standard-4",
      "db-n1-highmem-2", "db-n1-highmem-4"
    ], var.instance.spec.sizing.tier)
    error_message = "CloudSQL tier must be a valid machine type"
  }

  validation {
    condition     = var.instance.spec.sizing.disk_size >= 10 && var.instance.spec.sizing.disk_size <= 30720
    error_message = "Disk size must be between 10 GB and 30720 GB"
  }

  validation {
    condition     = var.instance.spec.sizing.read_replica_count >= 0 && var.instance.spec.sizing.read_replica_count <= 5
    error_message = "Read replica count must be between 0 and 5"
  }

  validation {
    condition = var.instance.spec.restore_config == null || !var.instance.spec.restore_config.restore_from_backup || (
      var.instance.spec.restore_config.source_instance_id != null &&
      var.instance.spec.restore_config.master_username != null &&
      var.instance.spec.restore_config.master_password != null
    )
    error_message = "When restore_from_backup is true, source_instance_id, master_username, and master_password are required"
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
    gcp_provider = object({
      attributes = object({
        project     = string
        credentials = string
      })
    })
    network = object({
      attributes = object({
        region                = string
        vpc_self_link         = string
        database_subnet_ids   = list(string)
        database_subnet_cidrs = list(string)
      })
    })
  })
}