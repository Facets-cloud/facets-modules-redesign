variable "instance" {
  description = "ECS cluster configuration."
  type = object({
    kind     = optional(string, "ecs_cluster")
    flavor   = optional(string, "aws")
    version  = optional(string, "1.0")
    disabled = optional(bool, false)
    spec = object({
      cluster_name                           = optional(string, "")
      capacity                               = optional(string, "ondemand")
      create_cloudwatch_log_group            = optional(bool, false)
      cloudwatch_log_group_name              = optional(string, "")
      cloudwatch_log_group_retention_in_days = optional(number, 90)
    })
    metadata = optional(object({ tags = optional(map(string), {}) }), {})
  })
}

variable "inputs" {
  description = "Structural dependencies for the module."
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
  })
}

variable "instance_name" { type = string }
variable "environment" {
  type = object({
    name        = optional(string, "default")
    unique_name = string
    cloud_tags  = optional(map(string), {})
  })
}
