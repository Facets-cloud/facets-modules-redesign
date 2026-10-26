variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      node_group_name = string
      instance_types  = list(string)
      capacity_type   = string
      min_size        = number
      max_size        = number
      desired_size    = number
      disk_size       = number
      ami_type        = string
      labels          = map(string)
      taints          = list(object({ key = string, value = string, effect = string }))
      tags            = map(string)
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
      attributes = optional(object({ aws_iam_role = optional(string), aws_region = optional(string), external_id = optional(string), session_name = optional(string) }), {})
      interfaces = optional(object({}), {})
    })
    kubernetes_details = object({
      attributes = optional(object({
        cloud_provider                    = optional(string)
        cluster_arn                       = optional(string)
        cluster_ca_certificate            = optional(string)
        cluster_endpoint                  = optional(string)
        cluster_iam_role_arn              = optional(string)
        cluster_id                        = optional(string)
        cluster_name                      = optional(string)
        cluster_location                  = optional(string)
        cluster_primary_security_group_id = optional(string)
        cluster_security_group_id         = optional(string)
        cluster_version                   = optional(string)
        kubernetes_provider_exec          = optional(object({ api_version = optional(string), args = optional(list(string)), command = optional(string) }))
        node_iam_role_arn                 = optional(string)
        node_iam_role_name                = optional(string)
        node_security_group_id            = optional(string)
        oidc_issuer_url                   = optional(string)
        oidc_provider                     = optional(string)
        oidc_provider_arn                 = optional(string)
        secrets                           = optional(list(string))
      }), {})
      interfaces = optional(object({
        kubernetes = optional(object({
          cluster_ca_certificate   = optional(string)
          host                     = optional(string)
          kubernetes_provider_exec = optional(object({ api_version = optional(string), args = optional(list(string)), command = optional(string) }))
          secrets                  = optional(list(string))
        }))
      }), {})
    })
    network_details = object({
      attributes = optional(object({ availability_zones = optional(list(string)), internet_gateway_id = optional(string), nat_gateway_ids = optional(list(string)), private_subnet_ids = optional(list(string)), public_subnet_ids = optional(list(string)), vpc_cidr_block = optional(string), vpc_endpoint_dynamodb_id = optional(string), vpc_endpoint_ecr_api_id = optional(string), vpc_endpoint_ecr_dkr_id = optional(string), vpc_endpoint_s3_id = optional(string), vpc_endpoints_security_group_id = optional(string), vpc_id = optional(string) }), {})
      interfaces = optional(object({}), {})
    })
  })
}
