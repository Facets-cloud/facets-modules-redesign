# ╔═══════════════════════════════════════════════════════════╗
# ║ AUTO-GENERATED from facets.yaml — DO NOT EDIT            ║
# ║                                                          ║
# ║ Any changes will be overwritten on next mutation command. ║
# ╚═══════════════════════════════════════════════════════════╝

variable "instance" {
  type = object({
    spec = object({
      cors_rules = optional(list(object({
        max_age_seconds = optional(number)
        method          = optional(list(string))
        origin          = optional(list(string))
        response_header = optional(list(string))
      })))
      force_destroy = optional(bool)
      kms_key_name  = string
      labels        = optional(object({}))
      lifecycle_rules = optional(list(object({
        action = object({
          storage_class = optional(string)
          type          = string
        })
        condition = optional(object({
          age                = optional(number)
          created_before     = optional(string)
          num_newer_versions = optional(number)
        }))
      })))
      location                 = optional(string)
      public_access_prevention = optional(string)
      retention_policy = optional(object({
        is_locked                = optional(bool)
        retention_period_seconds = number
      }))
      storage_class      = optional(string)
      versioning_enabled = optional(bool)
    })
  })
}

variable "instance_name" {
  type        = string
  description = "Resource name in the blueprint (architectural name, e.g. main-db, api)"
}

variable "environment" {
  type = object({
    name        = string                    # Environment name (e.g., dev, staging, prod)
    unique_name = string                    # Project + environment (globally unique, e.g., myapp-prod)
    cloud_tags  = optional(map(string), {}) # Cloud resource tags injected by Facets at deploy time
  })
  description = "Environment context. Use unique_name + instance_name for globally unique resource names."
}

variable "inputs" {
  type = object({
    cloud_account = object({
      attributes = optional(object({
        credentials = optional(string)
        project_id  = optional(string)
        region      = optional(string)
      }))
      interfaces = optional(object({}))
    })
  })
}
