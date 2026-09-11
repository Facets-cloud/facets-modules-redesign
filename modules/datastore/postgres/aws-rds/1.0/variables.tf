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
        instance_class     = string
        allocated_storage  = number
        read_replica_count = number
        # Optional: defaults to true, which is what main.tf hardcoded before this
        # attribute existed. Set false to match a single-AZ source instance.
        multi_az = optional(bool, true)
      })
      security_config = object({
        deletion_protection = bool
      })
      restore_config = optional(object({
        restore_from_backup           = bool
        source_db_instance_identifier = optional(string)
        master_username               = optional(string)
        master_password               = optional(string)
        # Snapshot restore (create-time only). snapshot_identifier may be the ARN of a
        # snapshot shared from another account; snapshot_kms_key_id is a key in THIS
        # account for the local copy, defaulting to alias/aws/rds when null.
        restore_from_snapshot = optional(bool, false)
        snapshot_identifier   = optional(string)
        snapshot_kms_key_id   = optional(string)
      }), { restore_from_backup = false })
      imports = optional(object({
        import_existing        = optional(bool, false)
        db_instance_identifier = optional(string)
        subnet_group_name      = optional(string)
        security_group_id      = optional(string)
        master_password        = optional(string)
      }), {})
    })
  })

  validation {
    condition     = !(var.instance.spec.restore_config.restore_from_backup && var.instance.spec.restore_config.restore_from_snapshot)
    error_message = "restore_config: restore_from_backup (point-in-time) and restore_from_snapshot are mutually exclusive - set at most one."
  }

  validation {
    condition     = !var.instance.spec.restore_config.restore_from_snapshot || try(length(var.instance.spec.restore_config.snapshot_identifier) > 0, false)
    error_message = "restore_config: snapshot_identifier is required when restore_from_snapshot is true."
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