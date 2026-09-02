variable "instance" {
  description = "Instance configuration"
  type = object({
    kind     = optional(string)
    flavor   = optional(string)
    version  = optional(string)
    disabled = optional(bool, false)
    spec = object({
      bindings = optional(list(object({
        role    = string
        members = optional(list(string), [])
      })), [])
      audit_configs = optional(list(object({
        service          = string
        audit_log_types  = list(string)
        exempted_members = optional(list(string), [])
      })), [])
    })
  })

  validation {
    condition = length(setsubtract(
      toset(flatten([
        for cfg in lookup(var.instance.spec, "audit_configs", []) : cfg.audit_log_types
      ])),
      toset(["ADMIN_READ", "DATA_READ", "DATA_WRITE"])
    )) == 0
    error_message = "Invalid audit_log_types value(s): ${join(", ", tolist(setsubtract(toset(flatten([for cfg in lookup(var.instance.spec, "audit_configs", []) : cfg.audit_log_types])), toset(["ADMIN_READ", "DATA_READ", "DATA_WRITE"]))))}. Valid values are ADMIN_READ, DATA_READ, DATA_WRITE."
  }

  validation {
    condition = length(distinct([
      for cfg in lookup(var.instance.spec, "audit_configs", []) : cfg.service
    ])) == length(lookup(var.instance.spec, "audit_configs", []))
    error_message = "Duplicate audit_configs service value(s): ${join(", ", distinct([for service in [for cfg in lookup(var.instance.spec, "audit_configs", []) : cfg.service] : service if length([for cfg in lookup(var.instance.spec, "audit_configs", []) : cfg.service if cfg.service == service]) > 1]))}. Each service can appear only once because google_project_iam_audit_config is authoritative per service."
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
