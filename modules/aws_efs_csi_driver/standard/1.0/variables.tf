variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      # Helm chart version
      chart_version = string

      # Resource sizing
      size = optional(object({
        controller = optional(object({
          cpu    = optional(string, "100m")
          memory = optional(string, "128Mi")
        }), {})
        node = optional(object({
          cpu    = optional(string, "100m")
          memory = optional(string, "128Mi")
        }), {})
      }), {})

      # User-supplied Helm values (deep-merged over computed values)
      values = optional(any, {})

      # Tags
      tags = optional(map(string), {})
    })
  })
}

variable "instance_name" {
  type        = string
  description = "Unique architectural name from blueprint"
}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    namespace   = optional(string)
    cloud_tags  = optional(map(string), {})
  })
  description = "Environment context including name and cloud tags"
}

variable "inputs" {
  type = object({
    cloud_account = object({
      attributes = optional(object({
        aws_region   = optional(string)
        aws_iam_role = optional(string)
        external_id  = optional(string)
        session_name = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
    kubernetes_details = object({
      attributes = optional(object({
        cluster_endpoint       = optional(string)
        cluster_ca_certificate = optional(string)
        cluster_name           = optional(string)
        cluster_version        = optional(string)
        cluster_arn            = optional(string)
        cluster_id             = optional(string)
        oidc_issuer_url        = optional(string)
        oidc_provider          = optional(string)
        oidc_provider_arn      = optional(string)
        node_security_group_id = optional(string)
        kubernetes_provider_exec = optional(object({
          api_version = optional(string)
          command     = optional(string)
          args        = optional(list(string))
        }), {})
      }), {})
      interfaces = optional(object({}), {})
    })
  })
  description = "Inputs from dependent modules"
}
