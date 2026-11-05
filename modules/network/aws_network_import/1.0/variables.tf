variable "instance" {
  description = "Instance configuration (import spec: vpc/subnets/endpoints/etc from live)"
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
  description = "Input references from other modules (cloud_account provides the aws provider)"
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
