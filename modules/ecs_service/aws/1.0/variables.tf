variable "instance" {
  description = "ECS service configuration."
  type = object({
    kind     = optional(string, "ecs_service")
    flavor   = optional(string, "aws")
    version  = optional(string, "1.0")
    disabled = optional(bool, false)
    spec = object({
      runtime = object({
        ports                    = map(object({ port = string, service_port = optional(string), protocol = string }))
        size                     = object({ cpu = number, memory = number })
        command                  = optional(list(string), [])
        args                     = optional(list(string), [])
        readonly_root_filesystem = optional(bool, true)
        autoscaling              = optional(object({ min = number, max = number }), { min = 1, max = 1 })
      })
      release           = object({ image = string, registry_name = optional(string, "") })
      env               = optional(map(string), {})
      cloud_permissions = optional(object({ aws = optional(object({ iam_policies = optional(map(object({ arn = string })), {}) }), {}) }), {})
      advanced          = optional(any, {})
    })
    metadata = optional(object({ name = optional(string), tags = optional(map(string), {}) }), {})
  })
}

variable "inputs" {
  type = object({
    cloud_account = object({
      attributes = optional(object({ aws_iam_role = optional(string), aws_region = optional(string), external_id = optional(string), session_name = optional(string) }), {})
      interfaces = optional(object({}), {})
    })
    network_details = object({
      attributes = object({ vpc_id = string, vpc_cidr_block = string, private_subnet_ids = list(string), public_subnet_ids = list(string) })
      interfaces = optional(object({}), {})
    })
    ecs_details = object({
      attributes = object({ cluster_arn = string, cluster_name = optional(string) })
      interfaces = optional(object({}), {})
    })
  })
}

variable "instance_name" { type = string }
variable "environment" {
  type = object({ name = optional(string, "default"), unique_name = string, cloud_tags = optional(map(string), {}), deployment_id = optional(string, ""), common_environment_variables = optional(map(string), {}) })
}
