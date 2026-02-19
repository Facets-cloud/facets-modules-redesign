# =============================================================================
# FACETS STANDARD VARIABLES
# =============================================================================

variable "instance" {
  description = "Facets instance configuration"
  type = object({
    spec = optional(object({
      container = optional(object({
        image   = optional(string)
        command = optional(list(string))
        args    = optional(list(string))
      }), {})
      gpu = optional(object({
        enabled = optional(bool, true)
        type    = optional(string, "nvidia-rtx-pro-6000")
      }), {})
      resources = optional(object({
        cpu    = optional(string, "20")
        memory = optional(string, "80Gi")
      }), {})
      job = optional(object({
        task_count   = optional(number, 1)
        parallelism  = optional(number, 1)
        max_retries  = optional(number, 3)
        task_timeout = optional(string, "3600s")
      }), {})
      env     = optional(map(string), {})
      secrets = optional(list(object({
        env_var     = optional(string)
        secret_name = optional(string)
        version     = optional(string, "latest")
      })), [])
      service_account = optional(string)
      vpc_access = optional(object({
        egress = optional(string, "PRIVATE_RANGES_ONLY")
      }))
    }), {})
  })
}

variable "instance_name" {
  description = "Name of the resource instance"
  type        = string
}

variable "environment" {
  description = "Environment configuration"
  type = object({
    name        = optional(string)
    unique_name = optional(string)
    cloud_tags  = optional(map(string), {})
  })
}

# =============================================================================
# INPUT RESOURCES
# =============================================================================

variable "inputs" {
  description = "Facets input resources. Required: cloud_account. Optional: network_details"
  type = object({
    cloud_account = object({
      attributes = object({
        project_id = string
        region     = string
      })
      interfaces = optional(object({}), {})
    })
    network_details = optional(object({
      attributes = optional(object({
        vpc_connector_name = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    }))
  })
}
