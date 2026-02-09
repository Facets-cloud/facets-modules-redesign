variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      # Karpenter installation settings
      karpenter_version     = string
      karpenter_replicas    = optional(number, 2)
      interruption_handling = optional(bool, false)

      # Tags
      tags = optional(map(string), {})
    })
  })

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.instance.spec.karpenter_version))
    error_message = "Karpenter version must be in semantic version format (e.g., 1.0.1)"
  }
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
    eks_details = object({
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
    kubernetes_details = object({
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
    network_details = object({
      attributes = object({
        vpc_id              = string
        private_subnet_ids  = list(string)
        public_subnet_ids   = list(string)
        database_subnet_ids = optional(list(string), [])
      })
    })
  })
  description = "Inputs from dependent modules"
}
