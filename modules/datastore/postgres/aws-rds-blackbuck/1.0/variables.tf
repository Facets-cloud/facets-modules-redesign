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
        # Optional: falls back to "pgadmin", which is what main.tf used unconditionally
        # before this attribute was reachable from the spec.
        master_username = optional(string, "pgadmin")
      })
      sizing = object({
        instance_class        = string
        allocated_storage     = number
        storage_type          = optional(string, "gp3")
        max_allocated_storage = optional(number, 0)
        read_replica_count    = number
        # Optional: defaults to true, which is what main.tf hardcoded before this
        # attribute existed. Set false to match a single-AZ source instance.
        multi_az = optional(bool, true)
      })
      security_config = object({
        deletion_protection = bool
        kms_key_arn         = optional(string)
        allowed_cidrs       = optional(list(string), [])
      })
      parameter_group = optional(object({
        parameters = optional(map(string), {})
      }), {})
      backup_config = optional(object({
        retention_days     = optional(number, 7)
        backup_window      = optional(string, "03:00-04:00")
        maintenance_window = optional(string, "sun:04:00-sun:05:00")
      }), {})
      network_config = optional(object({
        use_database_subnets = optional(bool, true)
      }), {})
      restore_config = optional(object({
        restore_from_backup           = bool
        source_db_instance_identifier = optional(string)
        master_username               = optional(string)
        master_password               = optional(string)
      }), { restore_from_backup = false })
      imports = optional(object({
        import_existing        = optional(bool, false)
        db_instance_identifier = optional(string)
        subnet_group_name      = optional(string)
        security_group_id      = optional(string)
        master_password        = optional(string)
      }))
    })
  })

  validation {
    condition = alltrue([
      for c in lookup(var.instance.spec.security_config, "allowed_cidrs", []) :
      !contains(["0.0.0.0/0", "::/0"], c)
    ])
    error_message = "allowed_cidrs must not contain an open CIDR (0.0.0.0/0 or ::/0). Grant the specific ranges that need access."
  }

  validation {
    condition = alltrue([
      for c in lookup(var.instance.spec.security_config, "allowed_cidrs", []) :
      can(cidrnetmask(c))
    ])
    error_message = "Every entry in allowed_cidrs must be a valid IPv4 CIDR."
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