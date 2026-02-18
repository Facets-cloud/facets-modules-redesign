variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      name   = string
      policy = any
      aws_iam_policy = any
      tags   = optional(map(string), {})
    })
  })
}


variable "instance_name" {
  type        = string
  default     = ""
  description = "Name of instance which is configured in facets"
}

variable "environment" {
  type = any
  default = {
    namespace = "default"
  }
}



variable "inputs" {
  type = object({
    cloud_account = object({
      attributes = optional(object({
        aws_iam_role = optional(string)
        aws_region   = optional(string)
        external_id  = optional(string)
        session_name = optional(string)
      }))
      interfaces = optional(object({}))
    })
  })
}
