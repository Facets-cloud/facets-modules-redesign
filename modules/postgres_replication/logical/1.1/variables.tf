# ╔═══════════════════════════════════════════════════════════╗
# ║ AUTO-GENERATED from facets.yaml — DO NOT EDIT            ║
# ║                                                          ║
# ║ Any changes will be overwritten on next mutation command. ║
# ╚═══════════════════════════════════════════════════════════╝

variable "instance" {
  type = object({
    spec = object({
      databases = optional(map(any), {})
      image     = optional(string, "postgres:17-alpine")
      namespace = optional(string, "")
      options = optional(object({
        allow_mutation                   = optional(bool, true)
        allow_schema_reset               = optional(bool, false)
        defer_secondary_indexes          = optional(bool, true)
        fail_on_missing_replica_identity = optional(bool, true)
        foreign_key_validation_mode      = optional(string, "strict")
        load_ready_timeout_seconds       = optional(number, 7200)
        max_concurrent_databases         = optional(number, 2)
        require_target_login_roles       = optional(bool, true)
        target_login_role_mode           = optional(string, "manage")
        target_autoresize_limit_gb       = optional(number, 0)
        target_disk_gb                   = optional(number, 0)
      }), {})
      slack = optional(object({
        channel_id   = optional(string, "")
        token_secret = optional(string, "")
      }), {})
      source = optional(object({
        admin_password = string
        admin_user     = string
        auth_db        = optional(string, "")
        host           = string
        login_roles    = optional(list(string), [])
        port           = optional(number, 5432)
        repl_password  = string
        repl_user      = string
      }))
      target = optional(object({
        admin_password = string
        admin_user     = string
        host           = string
        login_roles    = optional(list(string), [])
        port           = optional(number, 5432)
        repl_password  = string
        repl_user      = string
      }))
      tolerations = optional(object({}), {})
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
    kubernetes_details = object({
      attributes = optional(object({
        cloud_provider   = optional(string)
        cluster_endpoint = optional(string)
        cluster_id       = optional(string)
        cluster_location = optional(string)
        cluster_name     = optional(string)
      }))
      interfaces = optional(object({
        kubernetes = optional(object({
          cluster_ca_certificate = optional(string)
          host                   = optional(string)
        }))
      }))
    })
  })
}
