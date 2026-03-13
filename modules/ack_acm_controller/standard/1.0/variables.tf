variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      chart_version = string
      namespace     = optional(string)
      helm_values   = optional(map(any), {})
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
    kubernetes_node_pool_details = optional(object({
      attributes = optional(object({
        node_pool_name  = optional(string, "")
        node_class_name = optional(string, "")
        node_selector   = optional(map(string), {})
        taints = optional(list(object({
          key    = string
          value  = string
          effect = string
        })), [])
      }))
    }))
  })
  description = "Inputs from dependent modules"
}
