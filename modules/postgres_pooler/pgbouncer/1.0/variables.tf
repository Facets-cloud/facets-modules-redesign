# ╔═══════════════════════════════════════════════════════════╗
# ║ AUTO-GENERATED from facets.yaml — DO NOT EDIT            ║
# ║                                                          ║
# ║ Any changes will be overwritten on next mutation command. ║
# ╚═══════════════════════════════════════════════════════════╝

variable "instance" {
  type = object({
    spec = object({
      auth_type = optional(string)
      client_tls = optional(object({
        cert    = optional(string)
        sslmode = optional(string)
      }))
      default_pool_size = optional(number)
      dns_max_ttl       = optional(number)
      expose            = optional(string)
      health_checks = optional(object({
        liveness = optional(object({
          failure_threshold     = optional(number)
          initial_delay_seconds = optional(number)
          period_seconds        = optional(number)
          timeout_seconds       = optional(number)
        }))
        readiness = optional(object({
          failure_threshold     = optional(number)
          initial_delay_seconds = optional(number)
          period_seconds        = optional(number)
          timeout_seconds       = optional(number)
        }))
      }))
      image              = optional(string)
      listen_backlog     = optional(number)
      listen_port        = optional(number)
      max_client_conn    = optional(number)
      max_db_connections = optional(number)
      # any: optional metrics block (exporter + otel-collector sidecars). Loose
      # so new sub-fields don't require a variables.tf change; read via lookup.
      metrics           = optional(any, {})
      min_pool_size     = optional(number)
      namespace         = optional(string)
      pkt_buf           = optional(number)
      pool_mode         = optional(string)
      pool_reader       = optional(bool)
      pool_writer       = optional(bool)
      reader            = optional(object({}))
      replicas          = optional(number)
      reserve_pool_size = optional(number)
      resources = optional(object({
        cpu_limit      = optional(string)
        cpu_request    = optional(string)
        memory_limit   = optional(string)
        memory_request = optional(string)
      }))
      source = object({})
      users  = optional(map(any))
      writer = optional(object({}))
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
    node_pool = optional(object({
      # `any` (not a strict schema) so Terraform's object coercion does not DROP
      # node_selector / taints — the exact trap the service module avoids. Read
      # defensively in locals.
      attributes = optional(any, {})
      interfaces = optional(any, {})
    }))
  })
}
