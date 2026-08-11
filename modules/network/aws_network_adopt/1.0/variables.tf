variable "instance_name" {
  description = "Name of the instance"
  type        = string
}

variable "environment" {
  description = "Environment configuration"
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = map(string)
  })
}

variable "inputs" {
  description = "Input references from other modules"
  type = object({
    cloud_account = object({
      attributes = optional(object({
        aws_iam_role = optional(string)
        aws_region   = optional(string)
        external_id  = optional(string)
        session_name = optional(string)
      }))
      interfaces = optional(object({}))
    })
  })
}

variable "instance" {
  description = "Instance configuration (adopt: existing_vpc_id + subnet ids)"
  type        = any

  # Must supply an existing VPC id to adopt.
  validation {
    condition     = try(length(var.instance.spec.existing_vpc_id) > 0, false)
    error_message = "existing_vpc_id is required and must be a non-empty VPC id (e.g. vpc-0123...)."
  }

  # Must supply at least one private subnet id.
  validation {
    condition     = try(length(var.instance.spec.private_subnet_ids) > 0, false)
    error_message = "private_subnet_ids must list at least one existing subnet id."
  }
}
