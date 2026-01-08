#variable "cc_metadata" {
#  type = any
#  default = {
#    tenant_base_domain : "tenant.facets.cloud"
#  }
#}

variable "instance" {
  type = any
  default = {
    "flavor" = "aks",
    "spec" = {
      "instance_type"  = "",
      "min_node_count" = "",
      "max_node_count" = "",
      "disk_size"      = "",
      "zones"          = [],
      "taints"         = [],
      "node_labels"    = {}
    },
    "advanced" = {
      aks = {
        node_pool = {}
    } }
  }
}


variable "instance_name" {
  type    = string
  default = "mynodepool"
}
variable "environment" {
  type = any
  default = {
    namespace          = "testing",
    Cluster            = "azure-infra-dev",
    FacetsControlPlane = "facetsdemo.console.facets.cloud"
  }
}

variable "inputs" {
  type = object({
    kubernetes_details = optional(object({
      attributes = optional(object({
        oidc_issuer_url           = optional(string)
        cluster_id                = optional(string)
        cluster_name              = optional(string)
        cluster_fqdn              = optional(string)
        cluster_private_fqdn      = optional(string)
        cluster_endpoint          = optional(string)
        cluster_location          = optional(string)
        node_resource_group       = optional(string)
        resource_group_name       = optional(string)
        network_details           = optional(object({}))
        cluster_ca_certificate    = optional(string)
        client_certificate        = optional(string)
        client_key                = optional(string)
        automatic_channel_upgrade = optional(string)
        cloud_provider            = optional(string)
        secrets                   = optional(list(string))
      }))
      interfaces = optional(object({
        kubernetes = optional(object({
          host                   = optional(string)
          client_key             = optional(string)
          client_certificate     = optional(string)
          cluster_ca_certificate = optional(string)
          secrets                = optional(list(string))
        }))
      }))
    }))
    cloud_account = optional(object({
      attributes = optional(object({
        client_id       = optional(string)
        client_secret   = optional(string)
        subscription_id = optional(string)
        tenant_id       = optional(string)
      }))
      interfaces = optional(object({}))
    }))
  })
  default = {}
}