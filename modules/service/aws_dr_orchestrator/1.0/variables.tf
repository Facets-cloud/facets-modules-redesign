variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      ordered_steps           = list(string)
      require_manual_approval = optional(bool, true)
      validation_endpoints    = list(string)
      timeout_minutes         = optional(number, 60)
      rollback_on_failure     = optional(bool, true)
    })
  })
}

variable "instance_name" { type = string }

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = optional(map(string), {})
  })
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
    route53_failover = object({
      attributes = optional(object({}), {})
      interfaces = optional(object({}), {})
    })
    drs_replication = optional(object({
      attributes = optional(object({}), {})
      interfaces = optional(object({}), {})
    }))
  })
}
