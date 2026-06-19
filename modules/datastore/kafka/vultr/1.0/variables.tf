variable "instance" {
  description = "Managed Kafka cluster on Vultr with SASL_SSL auth and trusted-IP allow-listing"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      version_config = object({
        version = string
      })
      sizing = object({
        plan = string
      })
      features = optional(object({
        enable_kafka_rest      = optional(bool, false)
        enable_schema_registry = optional(bool, false)
        enable_kafka_connect   = optional(bool, false)
      }), {})
      network_access = optional(object({
        trusted_ips = optional(list(string), [])
      }), {})
    })
  })

  validation {
    condition     = contains(["3.8", "3.9", "4.0", "4.1"], var.instance.spec.version_config.version)
    error_message = "Kafka version must be one of: 3.8, 3.9, 4.0, 4.1."
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
    vultr_cloud_account = object({
      attributes = object({
        api_key = string
        region  = string
      })
    })
    network = optional(object({
      attributes = object({
        vpc_id = string
      })
    }))
  })
}
