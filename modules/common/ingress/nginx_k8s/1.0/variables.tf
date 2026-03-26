variable "instance" {
  type    = any
  default = {}
}

variable "instance_name" {
  type    = string
  default = ""
}

variable "inputs" {
  type = object({
    kubernetes_details = object({
      cloud_provider         = optional(string)
      cluster_id             = optional(string)
      cluster_name           = optional(string)
      cluster_location       = optional(string)
      cluster_endpoint       = optional(string)
      lb_service_record_type = optional(string)
    })
    kubernetes_node_pool_details = optional(object({
      attributes = optional(object({
        labels        = optional(any)
        taints        = optional(any)
        node_selector = optional(any)
      }))
    }))
    artifactories = optional(object({
      attributes = optional(object({
        registry_secrets_list = optional(any)
      }))
    }))
    cert_manager_details = optional(object({
      attributes = optional(object({
        cluster_issuer_dns  = optional(string)
        cluster_issuer_http = optional(string)
      }))
    }))
  })
  description = "Inputs from other modules"
}

variable "environment" {
  type    = any
  default = {}
}
