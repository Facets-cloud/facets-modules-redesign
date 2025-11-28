variable "instance" {
  description = "Creates ServiceAccount with admin role and registers OVH K8s credentials with Facets control plane"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec    = object({})
  })
}

variable "instance_name" {
  description = "The architectural name for the resource as added in the Facets blueprint designer."
  type        = string
}

variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name        = string
    unique_name = string
    namespace   = optional(string)
    cloud       = optional(string)
  })
}

variable "inputs" {
  description = "A map of inputs requested by the module developer."
  type = object({
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
        node_iam_role_arn      = string
        node_iam_role_name     = string
        node_security_group_id = string
        kubernetes_provider_exec = object({
          api_version = string
          command     = string
          args        = list(string)
        })
      })
    })
  })
}