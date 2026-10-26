variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      cluster_arn                = string
      service_arn                = string
      service_name               = string
      task_definition_arn        = string
      task_role_arn              = optional(string, "")
      desired_count              = number
      compute_mode               = optional(string, "LAUNCH_TYPE")
      launch_type                = optional(string, "FARGATE")
      capacity_provider_strategy = optional(list(object({ capacity_provider = string, weight = optional(number), base = optional(number) })), [])
      subnets                    = list(string)
      security_groups            = list(string)
      tags                       = map(string)
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
