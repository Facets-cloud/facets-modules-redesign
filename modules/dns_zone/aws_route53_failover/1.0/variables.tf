variable "instance" {
  type = object({
    kind     = optional(string)
    flavor   = optional(string)
    version  = optional(string)
    disabled = optional(bool, false)
    spec = object({
      hosted_zone_id            = string
      record_name               = string
      record_type               = optional(string, "A")
      primary_health_check_id   = optional(string, "")
      secondary_health_check_id = optional(string, "")
      ttl                       = optional(number, 60)
      evaluate_target_health    = optional(bool, false)
    })
  })
}

variable "instance_name" {
  type = string
}

variable "environment" {
  type = object({
    name        = optional(string)
    unique_name = optional(string)
    cloud_tags  = optional(map(string), {})
  })
  default = {}
}

variable "inputs" {
  type = object({
    cloud_account = object({
      attributes = optional(object({
        aws_iam_role = optional(string)
        aws_region   = optional(string)
        external_id  = optional(string)
        session_name = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
    primary_load_balancer = object({
      attributes = optional(object({}), {})
      interfaces = optional(object({}), {})
    })
    secondary_load_balancer = object({
      attributes = optional(object({}), {})
      interfaces = optional(object({}), {})
    })
  })
}
