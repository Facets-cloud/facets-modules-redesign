variable "instance" {
  description = "AWS ECS ALB configuration."
  type = object({
    kind     = optional(string, "load_balancer")
    flavor   = optional(string, "aws_ecs")
    version  = optional(string, "1.0")
    disabled = optional(bool, false)
    spec = object({
      public          = bool
      domain          = string
      certificate_arn = optional(string, "")
      rules = map(object({
        ecs_service_arn = string
        port            = number
        priority        = number
        path            = string
        domain_prefix   = optional(string, "")
        health_check = optional(object({
          protocol            = optional(string, "HTTP")
          path                = optional(string, "/")
          matcher             = optional(string, "200-499")
          interval            = optional(number, 30)
          timeout             = optional(number, 5)
          healthy_threshold   = optional(number, 2)
          unhealthy_threshold = optional(number, 2)
        }), {})
      }))
    })
    metadata = optional(object({ tags = optional(map(string), {}) }), {})
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
  })
}

variable "instance_name" { type = string }
variable "environment" { type = object({ name = optional(string, "default"), unique_name = string, cloud_tags = optional(map(string), {}) }) }
