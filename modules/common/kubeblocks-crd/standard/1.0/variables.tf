variable "instance" {
  description = "Installs KubeBlocks Custom Resource Definitions (CRDs) on Kubernetes cluster"
  type = object({
    kind   = string
    flavor = string
    spec = object({
      version = string
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
  description = "A map of inputs requested by the module developer."
  type = object({
  })
}