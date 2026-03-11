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
      resources = optional(object({
        cpu    = optional(string, "2")
        memory = optional(string, "4Gi")
      }), {})
      job = optional(object({
        task_count   = optional(number, 1)
        parallelism  = optional(number, 1)
        max_retries  = optional(number, 3)
        task_timeout = optional(string, "3600s")
      }), {})
      env = optional(map(string), {})
      secrets = optional(map(object({
        secret_name = string
        version     = optional(string, "latest")
      })), {})
      service_account = optional(string)
      vpc_access = optional(object({
        enabled = optional(bool, false)
        egress  = optional(string, "private-ranges-only")
      }), {})
      gcs_volumes = optional(map(object({
        bucket     = string
        mount_path = string
        read_only  = optional(bool, false)
      })), {})
      labels = optional(map(string), {})
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

variable "cluster" {
  description = "Cluster configuration"
  type        = object({})
  default     = {}
}

# =============================================================================
# INPUT RESOURCES
# =============================================================================

variable "inputs" {
  description = "Facets input resources"
  type = object({
    gcp_provider = object({
      attributes = object({
        project_id = string
        region     = string
      })
    })
    network = optional(object({
      attributes = object({
        vpc_name           = optional(string)
        vpc_self_link      = optional(string)
        subnet_name        = optional(string)
        vpc_connector_name = optional(string)
      })
    }), null)
  })
}
