variable "instance" {
  description = "Instance configuration"
  type = object({
    kind     = optional(string)
    flavor   = optional(string)
    version  = optional(string)
    disabled = optional(bool, false)
    spec = object({
      display_name        = string
      deletion_protection = optional(bool, true)
    })
  })
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
    parent_folder = optional(object({
      attributes = optional(object({
        folder_id   = optional(string)
        folder_name = optional(string)
        parent      = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    }))
  })
}
