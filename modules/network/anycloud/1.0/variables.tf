variable "instance" {
  type = object({
    spec = object({
      cidr = optional(string, "10.0.0.0/16")
      name = optional(string)
      aws = optional(object({
        auto_select_azs    = optional(bool, true)
        availability_zones = optional(list(string), [])
        nat_gateway = optional(object({
          strategy = optional(string, "single")
        }), {})
        vpc_endpoints = optional(object({
          enable_s3           = optional(bool)
          enable_dynamodb     = optional(bool)
          enable_ecr_api      = optional(bool)
          enable_ecr_dkr      = optional(bool)
          enable_eks          = optional(bool)
          enable_ec2          = optional(bool)
          enable_ssm          = optional(bool)
          enable_ssm_messages = optional(bool)
          enable_ec2_messages = optional(bool)
          enable_kms          = optional(bool)
          enable_logs         = optional(bool)
          enable_monitoring   = optional(bool)
          enable_sts          = optional(bool)
          enable_lambda       = optional(bool)
        }))
        tags = optional(map(string), {})
      }), {})
      gcp = optional(object({
        auto_select_zones = optional(bool, true)
        zones             = optional(list(string), [])
        enable_flow_logs  = optional(bool, false)
        firewall_rules = optional(object({
          allow_internal = optional(bool)
          allow_ssh      = optional(bool)
          allow_http     = optional(bool)
          allow_https    = optional(bool)
          allow_icmp     = optional(bool)
        }))
        vpc_connector = optional(object({
          enabled       = optional(bool, false)
          machine_type  = optional(string, "e2-micro")
          min_instances = optional(number, 2)
          max_instances = optional(number, 3)
        }), {})
        labels = optional(map(string), {})
      }), {})
    })
  })
}

variable "instance_name" {
  type        = string
  description = "Resource name in the blueprint (architectural name, e.g. main-db, api)"
}

variable "environment" {
  type = object({
    name        = string # Environment name (e.g., dev, staging, prod)
    unique_name = string # Project + environment (globally unique, e.g., myapp-prod)
    cloud_tags  = optional(map(string), {})
  })
  description = "Environment context. Use unique_name + instance_name for globally unique resource names."
}

variable "inputs" {
  type = object({
    cloud_account = object({
      attributes = optional(object({
        aws = optional(object({
          external_id = optional(string)
          region      = optional(string)
          role_arn    = optional(string)
        }))
        cloud_provider = optional(string)
        gcp = optional(object({
          access_token = optional(string)
          credentials  = optional(string)
          project_id   = optional(string)
          region       = optional(string)
        }))
      }))
      interfaces = optional(object({}))
    })
  })
}
