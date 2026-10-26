variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      vpc_id                          = string
      vpc_cidr_block                  = string
      availability_zones              = list(string)
      private_subnet_ids              = list(string)
      public_subnet_ids               = list(string)
      database_subnet_ids             = list(string)
      database_subnet_group_name      = optional(string, "")
      internet_gateway_id             = optional(string, "")
      nat_gateway_ids                 = optional(list(string), [])
      vpc_endpoint_dynamodb_id        = optional(string, "")
      vpc_endpoint_ecr_api_id         = optional(string, "")
      vpc_endpoint_ecr_dkr_id         = optional(string, "")
      vpc_endpoint_s3_id              = optional(string, "")
      vpc_endpoints_security_group_id = optional(string, "")
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
