variable "instance" {
  description = "Instance configuration"
  type = object({
    kind     = optional(string)
    flavor   = optional(string)
    version  = optional(string)
    disabled = optional(bool, false)
    spec = object({
      repository_id  = string
      location       = optional(string, "asia-south1")
      format         = optional(string, "DOCKER")
      description    = optional(string, "")
      kms_key_name   = optional(string, "artifacts")
      immutable_tags = optional(bool, false)
      cleanup_policies = optional(list(object({
        id         = string
        action     = string
        older_than = optional(string, "")
        keep_count = optional(number, 0)
      })), [])
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
    kms = optional(object({
      attributes = optional(object({
        keyring_id   = optional(string)
        keyring_name = optional(string)
        location     = optional(string)
        key_ids      = optional(map(string), {})
      }), {})
      interfaces = optional(object({}), {})
    }))
  })
}
