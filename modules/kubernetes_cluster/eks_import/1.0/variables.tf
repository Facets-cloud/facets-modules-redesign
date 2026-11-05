variable "instance" {
  description = "Instance configuration (import spec: cluster/roles/sgs/launch_templates/asgs/addons from live)"
  type        = any
}

variable "instance_name" {
  description = "Name of the instance"
  type        = string
}

variable "environment" {
  description = "Environment configuration"
  type        = any
}

variable "inputs" {
  description = "Input references from other modules (cloud_account provides the aws provider; network_details the VPC)"
  type = object({
    cloud_account = object({
      attributes = optional(object({
        aws_iam_role   = optional(string)
        aws_region     = optional(string)
        aws_account_id = optional(string)
        external_id    = optional(string)
        session_name   = optional(string)
      }))
      interfaces = optional(object({}))
    })
    network_details = object({
      attributes = optional(object({
        vpc_id             = optional(string)
        private_subnet_ids = optional(list(string))
        public_subnet_ids  = optional(list(string))
      }))
      interfaces = optional(object({}))
    })
  })
}
