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
        import_existing        = optional(bool, false)
        db_instance_identifier = optional(string)
        subnet_group_name      = optional(string)
        security_group_id      = optional(string)
        master_password        = optional(string)
      }))
    })
  })
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