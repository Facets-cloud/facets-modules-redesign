# ╔═══════════════════════════════════════════════════════════╗
# ║ AUTO-GENERATED from facets.yaml — DO NOT EDIT            ║
# ║                                                          ║
# ║ Any changes will be overwritten on next mutation command. ║
# ╚═══════════════════════════════════════════════════════════╝

variable "instance" {
  type = object({
    spec = object({
      attempt_deadline = optional(string)
      auth = optional(object({
        oauth_scope                 = optional(string)
        oauth_service_account_email = optional(string)
        oidc_audience               = optional(string)
        oidc_service_account_email  = optional(string)
      }))
      description = optional(string)
      paused      = optional(bool)
      retry_config = optional(object({
        max_backoff_duration = optional(string)
        max_doublings        = optional(number)
        max_retry_duration   = optional(string)
        min_backoff_duration = optional(string)
        retry_count          = optional(number)
      }))
      schedule = string
      target = object({
        body        = optional(string)
        headers     = optional(map(string), {})
        http_method = optional(string)
        uri         = string
      })
      time_zone = optional(string)
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
    gcp_provider = object({
      attributes = optional(object({
        credentials = optional(string)
        project_id  = optional(string)
        region      = optional(string)
      }))
      interfaces = optional(object({}))
    })
  })
}
