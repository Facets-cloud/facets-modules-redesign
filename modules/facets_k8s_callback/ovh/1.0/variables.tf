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
    name          = string
    unique_name   = string
    namespace     = optional(string)
    cloud         = optional(string)
    cluster_id    = optional(string)
    id            = optional(string)
    cc_host       = optional(string)
    cc_auth_token = optional(string)
  })
}

variable "inputs" {
  description = "A map of inputs requested by the module developer."
  type = object({
    kubernetes_details = object({
      attributes = object({
        cluster_endpoint       = string
        cluster_ca_certificate = string
        client_certificate     = string
        client_key             = string
      })
    })
  })
}
