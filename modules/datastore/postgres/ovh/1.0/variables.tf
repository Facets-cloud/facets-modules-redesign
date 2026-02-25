variable "instance" {
  description = "Managed PostgreSQL database on OVH Cloud with private network connectivity and SSL/TLS encryption"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version_config = object({
        version = string
      })
      sizing = object({
        plan        = string
        flavor      = string
        nodes_count = number
        disk_size   = number
      })
      advanced_config = optional(object({
        password_encryption               = optional(string, "md5")
        max_failover_replication_time_lag = optional(string, "60")
        io_combine_limit                  = optional(string, "16")
        io_max_combine_limit              = optional(string, "16")
        io_max_concurrency                = optional(string, "-1")
        io_method                         = optional(string, "worker")
        io_workers                        = optional(string, "3")
      }), {})
    })
  })

  validation {
    condition     = contains(["13", "14", "15", "16"], var.instance.spec.version_config.version)
    error_message = "PostgreSQL version must be one of: 13, 14, 15, 16."
  }

  validation {
    condition     = contains(["essential", "business", "enterprise"], var.instance.spec.sizing.plan)
    error_message = "Plan must be one of: essential, business, enterprise."
  }

  validation {
    condition     = var.instance.spec.sizing.nodes_count >= 1 && var.instance.spec.sizing.nodes_count <= 10
    error_message = "Nodes count must be between 1 and 10."
  }

  validation {
    condition     = var.instance.spec.sizing.disk_size >= 20 && var.instance.spec.sizing.disk_size <= 2000
    error_message = "Disk size must be between 20 and 2000 GB."
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
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  description = "A map of inputs requested by the module developer."
  type = object({
    ovh_provider = object({
      attributes = object({
        endpoint           = string
        application_key    = string
        application_secret = string
        consumer_key       = string
        project_id         = string
      })
    })
    network = object({
      attributes = object({
        network_id           = string
        network_name         = string
        network_cidr         = string
        openstack_network_id = string
        region               = string
        project_id           = string
        k8s_subnet_id        = string
        k8s_subnet_cidr      = string
        k8s_gateway_ip       = string
        gateway_id           = string
        db_subnet_id         = string
        db_subnet_cidr       = string
        lb_subnet_id         = string
        lb_subnet_cidr       = string
      })
    })
  })
}
