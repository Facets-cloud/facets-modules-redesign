variable "instance" {
  description = "MongoDB-compatible database using AWS DocumentDB service"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version_config = object({
        engine_version = string
        port           = number
      })
      sizing = object({
        instance_class = string
        instance_count = number
      })
      restore_config = optional(object({
        restore_from_snapshot = optional(bool, false)
        snapshot_identifier   = optional(string)
        master_username       = optional(string, "docdbadmin")
        master_password       = optional(string)
      }), {})
      imports = optional(object({
        cluster_identifier = optional(string)
        security_group_id  = optional(string)
        subnet_group_name  = optional(string)
      }), {})
    })
  })

  validation {
    condition     = contains(["4.0.0", "5.0.0", "6.0.0"], var.instance.spec.version_config.engine_version)
    error_message = "Engine version must be one of: 4.0.0, 5.0.0, 6.0.0"
  }

  validation {
    condition     = var.instance.spec.version_config.port >= 1024 && var.instance.spec.version_config.port <= 65535
    error_message = "Port must be between 1024 and 65535"
  }

  validation {
    condition = contains([
      "db.t3.medium", "db.t4g.medium", "db.r5.large",
      "db.r5.xlarge", "db.r6g.large", "db.r6g.xlarge"
    ], var.instance.spec.sizing.instance_class)
    error_message = "Instance class must be one of: db.t3.medium, db.t4g.medium, db.r5.large, db.r5.xlarge, db.r6g.large, db.r6g.xlarge"
  }

  validation {
    condition     = var.instance.spec.sizing.instance_count >= 1 && var.instance.spec.sizing.instance_count <= 16
    error_message = "Instance count must be between 1 and 16"
  }

  validation {
    condition = var.instance.spec.restore_config.restore_from_snapshot == false || (
      var.instance.spec.restore_config.snapshot_identifier != null &&
      var.instance.spec.restore_config.master_username != null &&
      var.instance.spec.restore_config.master_password != null
    )
    error_message = "When restore_from_snapshot is true, snapshot_identifier, master_username, and master_password are required"
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
        vpc_cidr_block     = string
      })
    })
  })

  validation {
    condition     = var.inputs.aws_provider.attributes.aws_iam_role != ""
    error_message = "AWS IAM role must be provided"
  }

  validation {
    condition     = var.inputs.vpc_details.attributes.vpc_id != ""
    error_message = "VPC ID must be provided"
  }

  validation {
    condition     = length(var.inputs.vpc_details.attributes.private_subnet_ids) > 0
    error_message = "At least one private subnet ID must be provided"
  }
}