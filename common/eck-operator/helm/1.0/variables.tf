variable "instance" {
  description = "Elastic Cloud on Kubernetes (ECK) Operator deployment configuration"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec    = object({})
  })
}

variable "instance_name" {
  description = "The architectural name for the ECK Operator resource"
  type        = string
}

variable "environment" {
  description = "Environment details"
  type = object({
    name        = string
    unique_name = string
  })
}

variable "inputs" {
  description = "Module dependencies"
  type = object({})
}