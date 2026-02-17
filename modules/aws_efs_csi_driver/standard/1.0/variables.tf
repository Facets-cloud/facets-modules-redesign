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
      attributes = object({
        aws_region     = string
        aws_account_id = string
        aws_iam_role   = string
        external_id    = optional(string)
        session_name   = optional(string)
      })
    })
    kubernetes_details = object({
      attributes = object({
        cluster_endpoint       = string
        cluster_ca_certificate = string
        cluster_name           = string
        cluster_version        = string
        cluster_arn            = string
        cluster_id             = string
        oidc_issuer_url        = string
        oidc_provider          = string
        oidc_provider_arn      = string
        node_security_group_id = string
        kubernetes_provider_exec = object({
          api_version = string
          command     = string
          args        = list(string)
        })
      })
    })
    network_details = object({
      attributes = object({
        vpc_id             = string
        vpc_cidr_block     = string
        private_subnet_ids = list(string)
        public_subnet_ids  = list(string)
      })
    })
  })
  description = "Inputs from dependent modules"
}
