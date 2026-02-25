variable "instance" {
  description = "Managed Valkey (Redis-compatible) cache on OVH Cloud with private network connectivity and TLS encryption"
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
      })
      advanced_config = optional(object({
        maxmemory_policy       = optional(string, "allkeys-lru")
        timeout                = optional(string, "300")
        notify_keyspace_events = optional(string, "")
        persistence            = optional(string, "rdb")
      }), {})
    })
  })

  validation {
    condition     = contains(["8.1", "8.0", "7.0", "6.2"], var.instance.spec.version_config.version)
    error_message = "Valkey version must be one of: 8.1, 8.0, 7.0, 6.2."
  }

  validation {
    condition     = contains(["essential", "business"], var.instance.spec.sizing.plan)
    error_message = "Plan must be one of: essential, business."
  }

  validation {
    condition     = var.instance.spec.sizing.nodes_count >= 1 && var.instance.spec.sizing.nodes_count <= 9
    error_message = "Nodes count must be between 1 and 9."
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
