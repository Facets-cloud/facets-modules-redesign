# =============================================================================
# FACETS STANDARD VARIABLES
# =============================================================================

variable "instance" {
  description = "Facets instance configuration"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      region      = optional(string) # Override queue region (e.g., asia-south1 for Mumbai)
      target_path = optional(string, "/process")
      retry_config = optional(object({
        max_attempts  = optional(number, 3)
        min_backoff   = optional(string, "10s")
        max_backoff   = optional(string, "3600s")
        max_doublings = optional(number, 4)
      }), {})
    })
  })
}

variable "instance_name" {
  description = "Name of the resource instance"
  type        = string
}

variable "environment" {
  description = "Environment configuration"
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = optional(map(string), {})
  })
}

# =============================================================================
# INPUT RESOURCES (from other modules via facets.yaml inputs)
# =============================================================================

variable "inputs" {
  description = "Input dependencies from other modules"
  type = object({
    cloud_account = object({
      attributes = object({
        project_id = string
        region     = string
      })
    })
    cloudrun = object({
      attributes = object({
        url           = string
        service_name  = string
        location      = string
        max_instances = optional(number, 10)
      })
    })
  })
}
