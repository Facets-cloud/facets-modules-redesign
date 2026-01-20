# Required Facets variables
variable "instance" {
  description = "Instance configuration from Facets"
  type        = any
}

variable "instance_name" {
  description = "Name of the instance from Facets. Must follow Kubernetes naming conventions (RFC 1123 DNS subdomain format)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]*[a-z0-9])?$", var.instance_name)) && length(var.instance_name) >= 3 && length(var.instance_name) <= 63
    error_message = "Instance name must be 3-63 characters, start and end with alphanumeric characters, and contain only lowercase letters, numbers, and hyphens (RFC 1123 DNS subdomain format)."
  }
}

variable "environment" {
  description = "Environment object from Facets containing name and other attributes"
  type        = any
}

variable "inputs" {
  description = "Input dependencies from Facets"
  type = object({
    kubernetes_details = object({
      cloud_provider         = optional(string)
      cluster_arn            = optional(string)
      cluster_ca_certificate = optional(string)
      cluster_endpoint       = optional(string)
      cluster_id             = optional(string)
      cluster_name           = optional(string)
      cluster_location       = optional(string)
      cluster_version        = optional(string)
      kubernetes_provider_exec = optional(object({
        api_version = optional(string)
        args        = optional(list(string))
        command     = optional(string)
      }))
      node_iam_role_arn      = optional(string)
      node_iam_role_name     = optional(string)
      node_security_group_id = optional(string)
      oidc_issuer_url        = optional(string)
      oidc_provider          = optional(string)
      oidc_provider_arn      = optional(string)
      secrets                = optional(list(string))
    })
    network_details = object({
      attributes = optional(object({
        availability_zones              = optional(list(string))
        internet_gateway_id             = optional(string)
        nat_gateway_ids                 = optional(list(string))
        private_subnet_ids              = optional(list(string))
        public_subnet_ids               = optional(list(string))
        vpc_cidr_block                  = optional(string)
        vpc_endpoint_dynamodb_id        = optional(string)
        vpc_endpoint_ecr_api_id         = optional(string)
        vpc_endpoint_ecr_dkr_id         = optional(string)
        vpc_endpoint_s3_id              = optional(string)
        vpc_endpoints_security_group_id = optional(string)
        vpc_id                          = optional(string)
      }))
      interfaces = optional(object({}))
    })
  })
}
