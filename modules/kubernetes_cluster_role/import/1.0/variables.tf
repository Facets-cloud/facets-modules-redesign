variable "instance" {
  description = "The resource object from the Facets blueprint"
  type        = any
}

variable "instance_name" {
  description = "Architectural name of the resource in the blueprint"
  type        = string
}

variable "environment" {
  description = "Environment context"
  type        = any
}

variable "inputs" {
  description = "Input dependencies from other modules (kubernetes_details provides the kubernetes provider)"
  type = object({
    kubernetes_details = any
  })
}
