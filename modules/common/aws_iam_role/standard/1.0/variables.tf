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
        }))
      }))
      interfaces = optional(object({}))
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