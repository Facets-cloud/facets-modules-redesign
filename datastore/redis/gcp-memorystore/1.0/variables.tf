# Module configuration variables
# All variables are automatically populated by the Facets platform

variable "instance" {
  description = "Managed Redis instance using Google Cloud Memorystore with high availability and security"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version_config = object({
        redis_version = string
      })
      sizing = object({
        memory_size_gb = number
        tier           = string
      })
      restore_config = object({
        restore_from_backup = bool
        source_instance_id  = optional(string)
      })
      security = object({
        enable_tls = bool
      })
      imports = optional(object({
        instance_id = optional(string)
      }))
    })
  })

  validation {
    condition = (
      var.instance.spec.sizing.tier == "BASIC" ||
      (var.instance.spec.sizing.tier == "STANDARD_HA" && var.instance.spec.sizing.memory_size_gb >= 5)
    )
    error_message = "Standard HA tier requires at least 5GB of memory for read replica support."
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
        project_id  = string
        credentials = string
      })
    })
    network = object({
      attributes = object({
        vpc_name                            = string
        vpc_self_link                       = string
        project_id                          = string
        region                              = string
        database_subnet_ids                 = list(string)
        database_subnet_cidrs               = list(string)
        private_services_connection_id      = string
        private_services_connection_status  = bool
        private_services_peering_connection = string
        private_services_range_address      = string
        private_services_range_id           = string
        private_services_range_name         = string
      })
    })
  })
}