variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      display_name   = string
      dashboard_json = string
    })
  })
}

variable "instance_name" {
  type        = string
  description = "Unique name for this dashboard resource"
}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  type = object({
    gcp_provider = object({
      attributes = object({
        project_id = string
        region     = string
      })
    })
  })
}
