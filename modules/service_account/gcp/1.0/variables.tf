variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      display_name = string
      description  = optional(string, "Managed by Facets")
      iam_bindings = optional(map(object({
        resource_type = string
        resource_name = optional(string)
        role          = string
        location      = optional(string) # Optional location override for regional resources
      })), {})
      create_key = optional(bool, false)
    })
  })
}

variable "instance_name" {
  type    = string
  default = "test_instance"
}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    namespace   = optional(string, "default")
    cloud_tags  = optional(map(string), {})
  })
  default = {
    name        = "default"
    unique_name = "default"
    namespace   = "default"
  }
}

variable "inputs" {
  type = object({
    cloud_account = object({
      attributes = object({
        project_id  = string
        project     = string
        credentials = string
        region      = string
      })
    })
  })
}
