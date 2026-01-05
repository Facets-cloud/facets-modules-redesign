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
    kubernetes_details = object({
      attributes = object({
        cluster_id             = string
        cluster_name           = string
        cluster_endpoint       = string
        cluster_location       = string
        node_resource_group    = string
        resource_group_name    = string
        cluster_ca_certificate = string
        oidc_issuer_url        = optional(string)
        network_details        = optional(any)
      })
      interfaces = optional(object({
        kubernetes = optional(object({
          host                   = string
          cluster_ca_certificate = string
          client_certificate     = optional(string)
          client_key             = optional(string)
        }))
      }))
    })
    cloud_account = object({
      attributes = object({
        subscription_id = string
        tenant_id       = string
        client_id       = optional(string)
        client_secret   = optional(string)
      })
    })
  })
}