variable "instance" {
  description = "Facets instance object containing spec and metadata"
  type = object({
    kind    = string
    flavor  = string
    version = string
    metadata = object({
      name = string
    })
    spec = any
  })
}

variable "instance_name" {
  description = "Name of the resource instance"
  type        = string
}

variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = map(string)
  })
}

variable "inputs" {
  description = "Input variables from dependencies"
  type = object({
    cloud_account = any
  })
}
