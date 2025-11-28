variable "instance" {
  description = "A managed PostgreSQL Aurora cluster with high availability, automated backups, and read replicas"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version_config = object({
        engine_version = string
        database_name  = string
      })
      sizing = object({
        instance_class     = string
        min_capacity       = number
        max_capacity       = number
        read_replica_count = number
      })
      restore_config = optional(object({
        restore_from_backup        = optional(bool)
        source_snapshot_identifier = optional(string)
        master_username            = optional(string)
        master_password            = optional(string)
      }), {})
      imports = optional(object({
        cluster_identifier          = optional(string)
        writer_instance_identifier  = optional(string)
        reader_instance_identifiers = optional(string)
        master_password             = optional(string)
      }), {})
    })
  })

  validation {
    condition = contains([
      "13.21",
      "14.18",
      "15.13",
      "16.9",
      "17.5"
    ], var.instance.spec.version_config.engine_version)
    error_message = "Engine version must be one of: 13.21, 14.18, 15.13, 16.9, 17.5"
  }

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.instance.spec.version_config.database_name))
    error_message = "Database name must start with a letter and contain only alphanumeric characters and underscores"
  }

  validation {
    condition     = length(var.instance.spec.version_config.database_name) >= 1 && length(var.instance.spec.version_config.database_name) <= 63
    error_message = "Database name must be between 1 and 63 characters"
  }

  validation {
    condition = contains([
      "db.t4g.medium", "db.r5.large",
      "db.r5.xlarge", "db.r5.2xlarge",
      "db.r6g.large", "db.r6g.xlarge"
    ], var.instance.spec.sizing.instance_class)
    error_message = "Instance class must be one of: db.t4g.medium, db.r5.large, db.r5.xlarge, db.r5.2xlarge, db.r6g.large, db.r6g.xlarge"
  }

  validation {
    condition     = var.instance.spec.sizing.min_capacity >= 0.5 && var.instance.spec.sizing.min_capacity <= 128
    error_message = "Minimum capacity must be between 0.5 and 128 ACU"
  }

  validation {
    condition     = var.instance.spec.sizing.max_capacity >= 1 && var.instance.spec.sizing.max_capacity <= 128
    error_message = "Maximum capacity must be between 1 and 128 ACU"
  }

  validation {
    condition     = var.instance.spec.sizing.read_replica_count >= 0 && var.instance.spec.sizing.read_replica_count <= 15
    error_message = "Read replica count must be between 0 and 15"
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
    aws_provider = object({
      attributes = object({
        aws_iam_role = string
        session_name = string
        external_id  = string
        aws_region   = string
      })
    })
    vpc_details = object({
      attributes = object({
        vpc_id             = string
        private_subnet_ids = list(string)
        availability_zones = list(string)
      })
    })
  })
}
