variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = optional(object({
      override_default_name   = optional(bool)
      override_name           = optional(string)
      description             = optional(string)
      kms_key_id              = optional(string)
      policy                  = optional(any)
      recovery_window_in_days = optional(number)
      rotation = optional(object({
        enabled    = optional(bool)
        lambda_arn = optional(string)
        rotation_rules = optional(object({
          automatically_after_days = optional(number)
          duration                 = optional(string)
          schedule_expression      = optional(string)
        }))
        rotate_immediately = optional(bool)
      }))
      secrets = optional(map(string))
    }))
    metadata = optional(object({
      tags = optional(map(string))
    }))
  })
}

variable "instance_name" {
  type        = string
  description = "Unique architectural name of the resource from blueprint"
}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    namespace   = string
    cloud_tags  = optional(map(string), {})
  })
}

variable "inputs" {
  type = object({
    cloud_account = optional(object({
      attributes = optional(object({
        aws_iam_role = optional(string)
        aws_region   = optional(string)
        external_id  = optional(string)
        session_name = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    }))
  })
  default = {}
}
