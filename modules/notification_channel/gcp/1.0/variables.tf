variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      channels = map(object({
        type          = string
        display_name  = optional(string)
        enabled       = optional(bool, true)
        email_address = optional(string)
        channel       = optional(string)
        auth_token    = optional(string)
        url           = optional(string)
        service_key   = optional(string)
        labels        = optional(map(string), {})
      }))
    })
  })
}

variable "instance_name" {
  type        = string
  description = "Unique name for this notification channel resource"
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
