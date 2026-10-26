variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      mode                   = string
      instance_ids           = optional(list(string), [])
      autoscaling_group_name = optional(string, "")
      ami_id                 = string
      instance_type          = string
      min_size               = optional(number, 0)
      max_size               = optional(number, 0)
      desired_capacity       = optional(number, 0)
      tags                   = map(string)
    })
  })
}

variable "instance_name" {
  type = string
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
    cloud_account   = object({ attributes = optional(object({ aws_iam_role = optional(string), aws_region = optional(string), external_id = optional(string), session_name = optional(string) }), {}), interfaces = optional(object({}), {}) })
    network_details = object({ attributes = optional(object({ availability_zones = optional(list(string)), internet_gateway_id = optional(string), nat_gateway_ids = optional(list(string)), private_subnet_ids = optional(list(string)), public_subnet_ids = optional(list(string)), vpc_cidr_block = optional(string), vpc_endpoint_dynamodb_id = optional(string), vpc_endpoint_ecr_api_id = optional(string), vpc_endpoint_ecr_dkr_id = optional(string), vpc_endpoint_s3_id = optional(string), vpc_endpoints_security_group_id = optional(string), vpc_id = optional(string) }), {}), interfaces = optional(object({}), {}) })
  })
}
