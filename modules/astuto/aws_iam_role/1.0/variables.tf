variable "instance" {
  description = "Instance configuration"
  type        = any
}

variable "instance_name" {
  description = "The architectural name for the resource"
  type        = string
}

variable "environment" {
  description = "An object containing details about the environment"
  type = object({
    name        = string
    unique_name = string
    namespace   = optional(string)
    cloud_tags  = map(string)
  })
}

variable "inputs" {
  description = "A map of inputs requested by the module developer"
  type = object({
    cloud_account = object({
      attributes = object({
        aws_iam_role = string
        aws_region   = string
        external_id  = string
        session_name = string
      })
      interfaces = optional(object({}))
    })
    eks_cluster = object({
      attributes = object({
        cluster_name       = string
        cluster_arn        = string
        oidc_provider_arn  = string
        oidc_issuer_url    = string
        cluster_endpoint   = string
        node_iam_role_arn  = optional(string)
        node_iam_role_name = optional(string)
      })
      interfaces = optional(object({}))
    })
  })
}
