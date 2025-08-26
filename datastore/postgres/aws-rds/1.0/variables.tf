variable "instance" {
  description = "Managed PostgreSQL database using Amazon RDS with secure defaults and backup support"
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
        allocated_storage  = number
        read_replica_count = number
      })
      security_config = object({
        deletion_protection = bool
      })
      restore_config = object({
        restore_from_backup           = bool
        source_db_instance_identifier = optional(string)
        master_username               = optional(string)
        master_password               = optional(string)
      })
      imports = optional(object({
        db_instance_identifier = optional(string)
      }))
    })
  })

  validation {
    condition     = contains(["13.15", "14.12", "15.7"], var.instance.spec.version_config.engine_version)
    error_message = "PostgreSQL version must be one of: 13.15, 14.12, 15.7"
  }

  validation {
    condition = contains([
      "db.t3.micro", "db.t3.small", "db.t3.medium",
      "db.m5.large", "db.m5.xlarge"
    ], var.instance.spec.sizing.instance_class)
    error_message = "Instance class must be one of: db.t3.micro, db.t3.small, db.t3.medium, db.m5.large, db.m5.xlarge"
  }

  validation {
    condition     = var.instance.spec.sizing.allocated_storage >= 20 && var.instance.spec.sizing.allocated_storage <= 65536
    error_message = "Allocated storage must be between 20 and 65536 GB"
  }

  validation {
    condition     = var.instance.spec.sizing.read_replica_count >= 0 && var.instance.spec.sizing.read_replica_count <= 5
    error_message = "Read replica count must be between 0 and 5"
  }

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.instance.spec.version_config.database_name))
    error_message = "Database name must start with a letter and contain only letters, numbers, and underscores"
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
        vpc_cidr_block     = string
      })
    })
  })
}