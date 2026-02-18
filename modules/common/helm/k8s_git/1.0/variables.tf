variable "instance" {
  type = object({
    spec = object({
      release_name   = optional(string)
      git_base_url   = optional(string, "github.com")
      git_repository = optional(string, "")
      git_owner      = optional(string, "")
      git_username   = optional(string, "")
      git_token      = optional(string, "")
      chart_path     = optional(string, "")
      git_ref        = optional(string, "main")
      namespace      = optional(string, "")
      wait_config = optional(object({
        wait    = optional(bool, true)
        timeout = optional(number, 300)
        }), {
        wait    = true
        timeout = 300
      })
      values = optional(map(any), {})
    })
  })

  validation {
    condition     = lookup(var.instance.spec, "git_repository", "") == "" || can(regex("^[a-zA-Z0-9._-]+$", lookup(var.instance.spec, "git_repository", "")))
    error_message = "git_repository must be a valid repository name (alphanumeric, dots, underscores, and hyphens only)."
  }

  validation {
    condition     = lookup(var.instance.spec, "namespace", "") == "" || can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", lookup(var.instance.spec, "namespace", "")))
    error_message = "namespace must be a valid Kubernetes namespace name or empty."
  }

  validation {
    condition = (
      lookup(lookup(var.instance.spec, "wait_config", {}), "timeout", 300) >= 1 &&
      lookup(lookup(var.instance.spec, "wait_config", {}), "timeout", 300) <= 3600
    )
    error_message = "wait_config.timeout must be between 1 and 3600 seconds."
  }
}

variable "instance_name" {
  type        = string
  description = "Unique name for the Helm release instance"
  default     = "test_instance"
}

variable "environment" {
  type = object({
    namespace   = optional(string)
    unique_name = optional(string)
    cloud_tags  = optional(map(string))
  })
  description = "Environment-specific configuration"
  default = {
    namespace = "default"
  }
}

variable "inputs" {
  type = object({
    kubernetes_details = object({
      attributes = optional(object({
        cloud_provider   = optional(string)
        cluster_id       = optional(string)
        cluster_name     = optional(string)
        cluster_location = optional(string)
        cluster_endpoint = optional(string)
      }))
      interfaces = optional(object({
        kubernetes = optional(object({
          cluster_ca_certificate = optional(string)
          host                   = optional(string)
        }))
      }))
    })
  })
  description = "Inputs from other modules"
}
