variable "instance" {
  description = "Creates and configures Microsoft Entra Workload Identity for AKS: user-assigned managed identity, federated identity credential to the AKS OIDC issuer, and annotated Kubernetes ServiceAccount for pod authentication."
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
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
    aks_cluster = object({
      resource_group_name    = string
      cluster_location       = string
      oidc_issuer_url        = string
      cluster_endpoint       = string
      cluster_ca_certificate = string
      client_certificate     = string
      client_key             = string
    })
  })
}