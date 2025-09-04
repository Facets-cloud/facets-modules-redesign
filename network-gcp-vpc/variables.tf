variable "instance" {
  description = "Creates a GCP VPC with configurable public subnets, private subnets, and database subnets across multiple zones"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      vpc_cidr          = string
      region            = optional(string, "us-central1")
      auto_select_zones = optional(bool, false)
      zones             = optional(list(string), [])
      public_subnets = object({
        count_per_zone = number
        subnet_size    = string
      })
      private_subnets = object({
        count_per_zone = number
        subnet_size    = string
      })
      database_subnets = object({
        count_per_zone = number
        subnet_size    = string
      })
      nat_gateway = object({
        strategy = string
      })
      firewall_rules = optional(object({
        allow_internal = optional(bool, true)
        allow_ssh      = optional(bool, true)
        allow_http     = optional(bool, true)
        allow_https    = optional(bool, true)
        allow_icmp     = optional(bool, true)
      }))
      private_google_access = optional(object({
        enable_private_subnets  = optional(bool, true)
        enable_database_subnets = optional(bool, true)
      }))
      private_services_connection = object({
        enable        = bool
        ip_cidr_range = optional(string)
        prefix_length = optional(number, 16)
      })
      tags = optional(map(string), {})
    })
  })

  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.instance.spec.vpc_cidr))
    error_message = "CIDR must be a valid IP block (e.g., 10.0.0.0/16)."
  }

  validation {
    condition     = contains(["256", "512", "1024", "2048", "4096", "8192"], var.instance.spec.public_subnets.subnet_size)
    error_message = "Public subnet size must be one of: 256, 512, 1024, 2048, 4096, 8192."
  }

  validation {
    condition     = contains(["256", "512", "1024", "2048", "4096", "8192"], var.instance.spec.private_subnets.subnet_size)
    error_message = "Private subnet size must be one of: 256, 512, 1024, 2048, 4096, 8192."
  }

  validation {
    condition     = contains(["256", "512", "1024", "2048", "4096", "8192"], var.instance.spec.database_subnets.subnet_size)
    error_message = "Database subnet size must be one of: 256, 512, 1024, 2048, 4096, 8192."
  }

  validation {
    condition     = contains(["single", "per_zone"], var.instance.spec.nat_gateway.strategy)
    error_message = "NAT gateway strategy must be either 'single' or 'per_zone'."
  }

  validation {
    condition     = length(var.instance.spec.region) > 0
    error_message = "GCP region cannot be empty."
  }

  validation {
    condition     = var.instance.spec.private_services_connection.ip_cidr_range == null || can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.instance.spec.private_services_connection.ip_cidr_range))
    error_message = "Private services IP CIDR range must be a valid IP block and not overlap with VPC CIDR."
  }

  validation {
    condition     = var.instance.spec.private_services_connection.prefix_length >= 16 && var.instance.spec.private_services_connection.prefix_length <= 24
    error_message = "Private services prefix length must be between 16 and 24."
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
    cloud_account = object({
      attributes = object({
        project     = string
        credentials = string
      })
    })
  })
}