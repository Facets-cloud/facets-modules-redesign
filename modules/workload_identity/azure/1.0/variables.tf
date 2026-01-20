variable "instance" {
  description = "Creates and configures Microsoft Entra Workload Identity for AKS: user-assigned managed identity, federated identity credential to the AKS OIDC issuer, and annotated Kubernetes ServiceAccount for pod authentication."
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      # Required fields
      identity_name         = string
      use_existing_identity = bool

      # Optional fields with defaults handled in locals.tf
      existing_identity_resource_id   = optional(string)
      service_account_namespace       = optional(string, "default")
      service_account_name            = optional(string, "workload-identity-sa")
      use_existing_k8s_sa             = optional(bool, false)
      annotate_k8s_sa                 = optional(bool, true)
      automount_service_account_token = optional(bool, false)
      tags                            = optional(map(string), {})
      role_assignments = optional(map(object({
        scope              = string
        role_definition_id = string
      })), {})
    })
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
  })
}
variable "inputs" {
  description = "Input dependencies from other resources defined in facets.yaml inputs section"
  type = object({
    # Required: Azure Cloud Account
    cloud_account = object({
      attributes = optional(object({
        subscription_id = optional(string)
        tenant_id       = optional(string)
        client_id       = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })

    # Required: AKS Cluster
    aks_cluster = object({
      attributes = optional(object({
        oidc_issuer_url        = optional(string)
        cluster_id             = optional(string)
        cluster_name           = optional(string)
        cluster_fqdn           = optional(string)
        cluster_private_fqdn   = optional(string)
        cluster_endpoint       = optional(string)
        cluster_location       = optional(string)
        node_resource_group    = optional(string)
        resource_group_name    = optional(string)
        cluster_ca_certificate = optional(string)
        client_certificate     = optional(string)
        client_key             = optional(string)
        cloud_provider         = optional(string)
        secrets                = optional(list(string), [])
      }), {})
      interfaces = optional(object({
        kubernetes = optional(object({
          host                   = optional(string)
          client_key             = optional(string)
          client_certificate     = optional(string)
          cluster_ca_certificate = optional(string)
          secrets                = optional(list(string), [])
        }))
      }), {})
    })
  })
}