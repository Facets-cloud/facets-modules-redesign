variable "instance" {
  description = "Creates or adopts an admin ServiceAccount and optionally registers K8s credentials with the Facets control plane"
  # spec is `any`: Facets only materialises the keys the resource doc actually wrote, so a strict
  # object type would reject the override-only adoption fields. Values are read with
  # lookup(local.spec, ...), which supplies the defaults.
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec    = any
  })
}

variable "instance_name" {
  description = "The architectural name for the resource as added in the Facets blueprint designer."
  type        = string
}

variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name           = string
    unique_name    = string
    namespace      = optional(string)
    cloud          = optional(string)
    environment_id = optional(string)
  })
}

variable "inputs" {
  description = "A map of inputs requested by the module developer."
  type = object({
    kubernetes_details = object({
      cluster_endpoint       = optional(string)
      cluster_ca_certificate = optional(string)
      cluster_name           = optional(string)
      cluster_version        = optional(string)
      cluster_id             = optional(string)
    })
  })
}
