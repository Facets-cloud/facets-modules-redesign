variable "instance" {
  description = "Facets instance object containing spec and metadata"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      loki_chart_version     = optional(string, "0.80.0")
      promtail_chart_version = optional(string, "6.16.6")
      namespace              = optional(string, "loki")
      retention_period       = optional(string, "744h")
      loki_size = optional(object({
        distributor = optional(object({
          replicas = optional(number, 1)
          requests = optional(object({
            cpu    = optional(string, "250m")
            memory = optional(string, "256Mi")
          }), {})
          limits = optional(object({
            cpu    = optional(string, "500m")
            memory = optional(string, "512Mi")
          }), {})
        }), {})
        ingester = optional(object({
          replicas = optional(number, 1)
          requests = optional(object({
            cpu    = optional(string, "250m")
            memory = optional(string, "512Mi")
          }), {})
          limits = optional(object({
            cpu    = optional(string, "500m")
            memory = optional(string, "1Gi")
          }), {})
        }), {})
        querier = optional(object({
          replicas = optional(number, 1)
          requests = optional(object({
            cpu    = optional(string, "250m")
            memory = optional(string, "256Mi")
          }), {})
          limits = optional(object({
            cpu    = optional(string, "500m")
            memory = optional(string, "512Mi")
          }), {})
        }), {})
        query_frontend = optional(object({
          replicas = optional(number, 1)
          requests = optional(object({
            cpu    = optional(string, "125m")
            memory = optional(string, "128Mi")
          }), {})
          limits = optional(object({
            cpu    = optional(string, "250m")
            memory = optional(string, "256Mi")
          }), {})
        }), {})
        compactor = optional(object({
          requests = optional(object({
            cpu    = optional(string, "100m")
            memory = optional(string, "256Mi")
          }), {})
          limits = optional(object({
            cpu    = optional(string, "250m")
            memory = optional(string, "512Mi")
          }), {})
        }), {})
      }), {})
      promtail_size = optional(object({
        requests = optional(object({
          cpu    = optional(string, "100m")
          memory = optional(string, "128Mi")
        }), {})
        limits = optional(object({
          cpu    = optional(string, "200m")
          memory = optional(string, "256Mi")
        }), {})
      }), {})
      query_timeout          = optional(number, 60)
      loki_custom_values     = optional(any, {})
      promtail_custom_values = optional(any, {})
    })
  })
}

variable "instance_name" {
  description = "Unique architectural name from blueprint"
  type        = string
}

variable "environment" {
  description = "An object containing details about the environment"
  type = object({
    name        = string
    unique_name = string
    namespace   = optional(string)
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  description = "Input variables from dependencies"
  type = object({
    cloud_account = object({
      attributes = object({
        aws_region   = string
        aws_iam_role = string
        external_id  = optional(string)
        session_name = optional(string)
      })
    })
    eks_details = object({
      attributes = object({
        cluster_endpoint                  = string
        cluster_ca_certificate            = string
        cluster_name                      = string
        cluster_version                   = optional(string)
        cluster_arn                       = optional(string)
        cluster_id                        = optional(string)
        cluster_location                  = optional(string)
        cluster_primary_security_group_id = optional(string)
        cluster_security_group_id         = optional(string)
        oidc_issuer_url                   = string
        oidc_provider                     = string
        oidc_provider_arn                 = string
        node_iam_role_arn                 = optional(string)
        node_iam_role_name                = optional(string)
        node_security_group_id            = optional(string)
        kubernetes_provider_exec = optional(object({
          api_version = string
          command     = string
          args        = list(string)
        }))
      })
    })
    s3_details = object({
      attributes = object({
        bucket_name                 = string
        bucket_arn                  = string
        region                      = string
        bucket_domain_name          = optional(string)
        bucket_regional_domain_name = optional(string)
        read_only_iam_policy_arn    = optional(string)
        read_write_iam_policy_arn   = optional(string)
      })
    })
  })
}
