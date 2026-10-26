variable "instance" {
  type = object({
    kind     = optional(string)
    flavor   = optional(string)
    version  = optional(string)
    disabled = optional(bool, false)
    spec = object({
      load_balancer_arn = string
      scheme            = optional(string, "internet-facing")
      ip_address_type   = optional(string, "ipv4")
      subnet_ids        = optional(list(string), [])
      listeners = optional(list(object({
        port             = number
        protocol         = string
        target_group_arn = optional(string, "")
        certificate_arn  = optional(string, "")
        ssl_policy       = optional(string, "")
      })), [])
      target_group_arns = optional(list(string), [])
      tags              = optional(map(string), {})
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
    network_details = object({
      attributes = optional(object({
        availability_zones              = optional(list(string), [])
        internet_gateway_id             = optional(string)
        nat_gateway_ids                 = optional(list(string), [])
        private_subnet_ids              = optional(list(string), [])
        public_subnet_ids               = optional(list(string), [])
        vpc_cidr_block                  = optional(string)
        vpc_endpoint_dynamodb_id        = optional(string)
        vpc_endpoint_ecr_api_id         = optional(string)
        vpc_endpoint_ecr_dkr_id         = optional(string)
        vpc_endpoint_s3_id              = optional(string)
        vpc_endpoints_security_group_id = optional(string)
        vpc_id                          = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
  })
}
