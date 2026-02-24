variable "instance_name" {
  description = "Name of the log collector instance"
  type        = string
}

variable "environment" {
  description = "Environment configuration"
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = map(string)
    namespace   = string
    cloud       = optional(string)
    default_tolerations = optional(list(object({
      key      = string
      value    = optional(string)
      operator = string
      effect   = string
    })), [])
  })
}

variable "inputs" {
  description = "Input references from other modules"
  type = object({
    kubernetes_details = object({
      attributes = optional(object({
        cluster_name           = optional(string)
        cluster_endpoint       = optional(string)
        cluster_ca_certificate = optional(string)
        facets_dedicated_tolerations = optional(list(object({
          key      = string
          value    = optional(string)
          operator = string
          effect   = string
        })), [])
      }), {})
      interfaces = optional(object({}), {})
    })
    prometheus = optional(object({
      attributes = optional(object({
        prometheus_url    = optional(string)
        alertmanager_url  = optional(string)
        grafana_namespace = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    }), null)
    aws_cloud_account = optional(object({
      attributes = optional(object({
        aws_region   = optional(string)
        aws_iam_role = optional(string)
        external_id  = optional(string)
        session_name = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    }), null)
  })
}

variable "instance" {
  description = "Instance configuration (spec, metadata, advanced)"
  type        = any

  # Validate retention_days range
  validation {
    condition = try(
      lookup(var.instance.spec, "retention_days", 7) >= 1 && lookup(var.instance.spec, "retention_days", 7) <= 365,
      true
    )
    error_message = "retention_days must be between 1 and 365 days."
  }

  # Validate storage size format
  validation {
    condition = try(
      can(regex("^[0-9]+(Mi|Gi|Ti)$", lookup(var.instance.spec, "storage_size", "5Gi"))),
      true
    )
    error_message = "storage_size must be in format like '5Gi', '10Gi', '1Ti'."
  }

  # Validate ingester_pvc_size format
  validation {
    condition = try(
      can(regex("^[0-9]+(Mi|Gi|Ti)$", lookup(var.instance.spec, "ingester_pvc_size", "5Gi"))),
      true
    )
    error_message = "ingester_pvc_size must be in format like '5Gi', '10Gi', '1Ti'."
  }

  # Validate querier_pvc_size format
  validation {
    condition = try(
      can(regex("^[0-9]+(Mi|Gi|Ti)$", lookup(var.instance.spec, "querier_pvc_size", "5Gi"))),
      true
    )
    error_message = "querier_pvc_size must be in format like '5Gi', '10Gi', '1Ti'."
  }

  # Validate loki_query_timeout range
  validation {
    condition = try(
      lookup(var.instance.spec, "loki_query_timeout", 60) >= 10 && lookup(var.instance.spec, "loki_query_timeout", 60) <= 600,
      true
    )
    error_message = "loki_query_timeout must be between 10 and 600 seconds."
  }

  # Validate Route53 fields when enabled
  validation {
    condition = try(
      lookup(var.instance.spec, "enable_route53_record", false) == false ||
      (
        lookup(var.instance.spec, "route53_domain_prefix", "") != "" &&
        lookup(var.instance.spec, "route53_zone_id", "") != "" &&
        lookup(var.instance.spec, "route53_base_domain", "") != ""
      ),
      true
    )
    error_message = "When enable_route53_record is true, route53_domain_prefix, route53_zone_id, and route53_base_domain must all be provided."
  }
}
