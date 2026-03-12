variable "instance" {
  description = "The full Facets resource instance object"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      bucket_name         = string
      location            = optional(string)
      versioning_enabled  = optional(bool)
      force_destroy       = optional(bool)
      storage_class       = optional(string)
    })
  })
}

variable "instance_name" {
  description = "Unique architectural name from blueprint"
  type        = string
}

variable "environment" {
  description = "The target environment"
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  description = "Resource dependencies and inputs"
  type = object({
    cloud_account = object({
      attributes = object({
        gcp_project_id = string
        gcp_region     = string
      })
    })
  })
}
