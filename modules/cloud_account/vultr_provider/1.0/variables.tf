variable "instance" {
  description = "Configures the Vultr Terraform provider with API key authentication"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      api_key = string
      region  = string
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
