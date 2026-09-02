variable "instance" {
  description = "Instance configuration"
  type = object({
    kind     = optional(string)
    flavor   = optional(string)
    version  = optional(string)
    disabled = optional(bool, false)
    spec = object({
      workload_identity_pool_id = optional(string, "github")
      provider_id               = optional(string, "github-oidc")
      github_org                = string
      attribute_condition       = optional(string, "")
      service_account_email     = string
      repositories              = list(string)
    })
  })

  validation {
    condition     = trimspace(var.instance.spec.github_org) != ""
    error_message = "github_org must not be empty."
  }

  validation {
    condition     = trimspace(var.instance.spec.service_account_email) != ""
    error_message = "service_account_email must not be empty."
  }

  validation {
    condition     = length(var.instance.spec.repositories) > 0
    error_message = "repositories must contain at least one GitHub repository."
  }
}

variable "instance_name" {
  description = "Name of the instance"
  type        = string
  default     = "test_instance"
}

variable "environment" {
  description = "Environment configuration"
  type = object({
    name         = optional(string, "default")
    unique_name  = optional(string, "default")
    namespace    = optional(string, "default")
    cloud_tags   = optional(map(string), {})
    cluster_code = optional(string, "")
  })
  default = {}
}

variable "inputs" {
  description = "Input references from other modules"
  type = object({
    cloud_account = object({
      attributes = optional(object({
        credentials           = optional(string)
        project_id            = optional(string)
        org_id                = optional(string)
        org_name              = optional(string)
        billing_account       = optional(string)
        quota_project         = optional(string)
        user_project_override = optional(bool)
        region                = optional(string)
        secrets               = optional(list(string), [])
      }), {})
      interfaces = optional(object({}), {})
    })
    project = object({
      attributes = optional(object({
        project_id     = optional(string)
        project_number = optional(string)
        project_name   = optional(string)
        folder_id      = optional(string)
        enabled_apis   = optional(list(string), [])
      }), {})
      interfaces = optional(object({}), {})
    })
  })
}
