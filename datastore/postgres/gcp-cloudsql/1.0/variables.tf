variable "instance" {
  description = "Managed PostgreSQL database using Google Cloud SQL with secure defaults and high availability"
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
      restore_config = object({
        restore_from_backup = bool
        source_instance_id  = optional(string)
        master_username     = optional(string)
        master_password     = optional(string)
      })
      imports = optional(object({
        instance_id   = optional(string)
        database_name = optional(string)
        user_name     = optional(string)
        master_password = optional(string)
      }))
    })
  })

  validation {
    condition     = contains(["13", "14", "15"], var.instance.spec.version_config.version)
    error_message = "PostgreSQL version must be one of: 13, 14, 15"
  }

  validation {
    condition = contains([
      "db-f1-micro", "db-g1-small", "db-n1-standard-1",
      "db-n1-standard-2", "db-n1-standard-4"
    ], var.instance.spec.sizing.tier)
    error_message = "Instance tier must be one of: db-f1-micro, db-g1-small, db-n1-standard-1, db-n1-standard-2, db-n1-standard-4"
  }

  validation {
    condition     = var.instance.spec.sizing.disk_size >= 10 && var.instance.spec.sizing.disk_size <= 30720
    error_message = "Disk size must be between 10 and 30720 GB"
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
    gcp_provider = object({
      attributes = object({
        project     = string
        credentials = string
      })
    })
    network = object({
      attributes = object({
        vpc_self_link                       = string
        vpc_id                              = string
        vpc_name                            = string
        region                              = string
        project_id                          = string
        private_services_connection_id      = string
        private_services_connection_status  = bool
        private_services_range_name         = string
        private_services_range_id           = string
        private_services_range_address      = string
        private_services_peering_connection = string
        private_subnet_ids                  = list(string)
        database_subnet_ids                 = list(string)
        private_subnet_cidrs                = list(string)
        database_subnet_cidrs               = list(string)
        public_subnet_ids                   = list(string)
        public_subnet_cidrs                 = list(string)
        firewall_rule_ids                   = list(string)
        nat_gateway_ids                     = list(string)
        router_ids                          = list(string)
        zones                               = list(string)
      })
    })
  })
}