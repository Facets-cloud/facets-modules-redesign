variable "instance" {
  description = "Facets resource instance."
  type        = any
}

variable "instance_name" {
  description = "Facets resource instance name."
  type        = string
}

variable "environment" {
  description = "Facets environment object."
  type        = any
}

variable "inputs" {
  description = "Facets input resources."
  type = object({
    aws_provider = any
    gcp_provider = any
  })
}
