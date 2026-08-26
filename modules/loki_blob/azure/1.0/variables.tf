variable "instance" {
  description = "Creates Azure Blob Storage infrastructure for Loki log aggregation with AKS workload identity federation."
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      storage_config = object({
        container_name    = string
        account_tier      = string
        replication_type  = string
        enable_versioning = optional(bool, false)
        retention_days    = optional(number, 0)
      })
      workload_identity = object({
        service_account_namespace = string
        service_account_name      = string
      })
      loki_config = optional(object({
        query_timeout = optional(number, 60)
      }))
      tags = optional(map(string), {})
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
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  description = "Input dependencies from other resources defined in facets.yaml inputs section."
  type = object({
    cloud_account = object({
      attributes = optional(object({
        subscription_id = optional(string)
        tenant_id       = optional(string)
        client_id       = optional(string)
        client_secret   = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
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
