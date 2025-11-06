variable "instance" {
  description = "Managed MySQL database instance on AWS RDS with high availability, automated backups, and read replicas"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version_config = object({
        version         = string
        database_name   = string
        master_username = string
      })
      sizing = object({
        instance_class        = string
        allocated_storage     = number
        max_allocated_storage = number
        storage_type          = string
        read_replica_count    = number
      })
      restore_config = object({
        restore_from_backup           = bool
        source_db_instance_identifier = optional(string)
        restore_master_username       = optional(string)
        restore_master_password       = optional(string)
      })
      imports = optional(object({
        db_instance_identifier = optional(string)
        db_subnet_group_name   = optional(string)
        security_group_id      = optional(string)
        master_password        = optional(string)
      }))
    })
  })

  validation {
    condition     = contains(["5.7", "8.0", "8.4"], var.instance.spec.version_config.version)
    error_message = "MySQL version must be one of: 5.7, 8.0, 8.4"
  }

  validation {
    condition     = contains(["db.t3.micro", "db.t3.small", "db.t3.medium", "db.t3.large", "db.m5.large", "db.m5.xlarge", "db.m5.2xlarge"], var.instance.spec.sizing.instance_class)
    error_message = "Instance class must be a valid RDS instance type"
  }

  validation {
    condition     = var.instance.spec.sizing.allocated_storage >= 20 && var.instance.spec.sizing.allocated_storage <= 65536
    error_message = "Allocated storage must be between 20 and 65536 GB"
  }

  validation {
    condition     = var.instance.spec.sizing.max_allocated_storage >= 0 && var.instance.spec.sizing.max_allocated_storage <= 65536
    error_message = "Max allocated storage must be between 0 and 65536 GB"
  }

  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.instance.spec.sizing.storage_type)
    error_message = "Storage type must be one of: gp2, gp3, io1, io2"
  }

  validation {
    condition     = var.instance.spec.sizing.read_replica_count >= 0 && var.instance.spec.sizing.read_replica_count <= 5
    error_message = "Read replica count must be between 0 and 5"
  }

  validation {
    condition     = length(var.instance.spec.version_config.database_name) >= 1 && length(var.instance.spec.version_config.database_name) <= 64
    error_message = "Database name must be between 1 and 64 characters"
  }

  validation {
    condition     = length(var.instance.spec.version_config.master_username) >= 1 && length(var.instance.spec.version_config.master_username) <= 16
    error_message = "Master username must be between 1 and 16 characters"
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
    aws_cloud_account = object({
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
        public_subnet_ids  = list(string)
        availability_zones = list(string)
        vpc_cidr_block     = string
      })
    })
  })
}