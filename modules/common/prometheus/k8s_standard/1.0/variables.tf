variable "instance" {
  description = "The JSON representation of the resource in the Facets blueprint."
  type        = any
}

variable "instance_name" {
  description = "The architectural name for the resource as added in the Facets blueprint designer."
  type        = string
}

variable "environment" {
  description = "An object containing details about the environment."
  type        = any
}

variable "inputs" {
  description = "A map of inputs requested by the module developer."
  type = object({
    kubernetes_details = object({
      attributes = object({
        cluster_endpoint = string
        cluster_name     = optional(string)
        cluster_id       = optional(string)
      })
      interfaces = optional(object({
        kubernetes = optional(object({
          host                   = string
          cluster_ca_certificate = string
        }))
      }))
    })
    kubernetes_node_pool_details = optional(object({
      node_selector = optional(map(string))
      taints = optional(map(object({
        key    = string
        value  = string
        effect = string
      })))
    }))
  })
}

variable "cc_metadata" {
  description = "Facets control plane metadata"
  type        = any
  default     = {}
}