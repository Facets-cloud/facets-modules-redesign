variable "instance" {
  description = "Managed Redis cache using AWS ElastiCache with security and high availability defaults"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version_config = object({
        redis_version = string
        node_type     = string
      })
      sizing = object({
        num_cache_nodes          = number
        parameter_group_name     = string
        snapshot_retention_limit = number
      })
      restore_config = optional(object({
        restore_from_snapshot = bool
        snapshot_name         = optional(string)
        }), {
        restore_from_snapshot = false
        snapshot_name         = null
      })
      imports = optional(object({
        cluster_id        = optional(string)
        subnet_group_name = optional(string)
        security_group_id = optional(string)
      }), {})
    })
  })

  validation {
    condition     = contains(["7.0"], var.instance.spec.version_config.redis_version)
    error_message = "Redis version must be: 7.0"
  }

  validation {
    condition = contains([
      "cache.t3.micro", "cache.t3.small", "cache.t3.medium",
      "cache.m6g.large", "cache.m6g.xlarge"
    ], var.instance.spec.version_config.node_type)
    error_message = "Node type must be one of: cache.t3.micro, cache.t3.small, cache.t3.medium, cache.m6g.large, cache.m6g.xlarge"
  }

  validation {
    condition     = var.instance.spec.sizing.num_cache_nodes >= 1 && var.instance.spec.sizing.num_cache_nodes <= 6
    error_message = "Number of cache nodes must be between 1 and 6"
  }

  validation {
    condition     = var.instance.spec.sizing.snapshot_retention_limit >= 0 && var.instance.spec.sizing.snapshot_retention_limit <= 35
    error_message = "Snapshot retention limit must be between 0 and 35 days"
  }

  validation {
    condition     = !var.instance.spec.restore_config.restore_from_snapshot || var.instance.spec.restore_config.snapshot_name != null
    error_message = "Snapshot name must be provided when restore_from_snapshot is true"
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
}