variable "instance" {
  description = "Facets default providers — base AWS provider configuration used for legacy aliases (e.g., aws3tooling)."
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      aws_region = optional(string, "")
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
  description = "Module has no upstream inputs — it is a foundational provider module."
  type        = object({})
}
