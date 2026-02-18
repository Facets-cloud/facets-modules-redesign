variable "instance_name" {
  description = "Unique architectural name from blueprint"
  type        = string
}

variable "environment" {
  description = "Environment context including name and cloud tags"
  type = object({
    name        = string
    unique_name = string
    namespace   = optional(string)
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  description = "Inputs from dependent modules"
  type = object({
    kubernetes_details = optional(object({
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
    }))
    cloud_account = object({
      attributes = object({
        aws_region     = string
        aws_account_id = string
        aws_iam_role   = string
        external_id    = optional(string)
        session_name   = optional(string)
      })
    })
  })
}

variable "instance" {
  description = "Instance configuration for AWS IAM Role"
  type = object({
    kind     = string
    flavor   = string
    version  = string
    metadata = optional(map(string), {})
    spec = object({
      irsa = optional(object({
        service_accounts = object({})
        oidc_providers   = optional(object({}), {})
      }))
      policies = object({})
      tags     = optional(map(string), {})
    })
  })
}