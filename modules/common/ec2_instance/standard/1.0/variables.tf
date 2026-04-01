variable "instance" {
  description = "EC2 instance configuration"
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      name = optional(string)

      # Instance Configuration
      ami_id        = optional(string)
      instance_type = optional(string)

      # Network Configuration
      vpc_id                 = optional(string)
      vpc_cidr               = optional(string)
      subnet_id              = optional(list(string))
      availability_zone      = optional(string)
      vpc_security_group_ids = optional(list(string))

      # Security Group Configuration
      create_security_group      = optional(bool)
      security_group_name        = optional(string)
      security_group_description = optional(string)
      ingress_rules = optional(list(object({
        ip_protocol                  = optional(string)
        from_port                    = optional(number)
        to_port                      = optional(number)
        cidr_ipv4                    = optional(string)
        cidr_ipv6                    = optional(string)
        referenced_security_group_id = optional(string)
        description                  = optional(string)
      })))
      egress_rules = optional(list(object({
        ip_protocol                  = optional(string)
        from_port                    = optional(number)
        to_port                      = optional(number)
        cidr_ipv4                    = optional(string)
        cidr_ipv6                    = optional(string)
        referenced_security_group_id = optional(string)
        description                  = optional(string)
      })))

      # Placement Group Configuration
      create_placement_group   = optional(bool)
      placement_group_name     = optional(string)
      placement_group_strategy = optional(string)
      placement_group_id       = optional(string)

      # IAM Configuration
      create_iam_instance_profile = optional(bool)
      iam_role_name               = optional(string)
      iam_role_description        = optional(string)
      iam_role_policies           = optional(map(string))
      iam_instance_profile        = optional(string)

      # Instance Features
      create_eip                  = optional(bool)
      associate_public_ip_address = optional(bool)
      disable_api_stop            = optional(bool)
      disable_api_termination     = optional(bool)
      hibernation                 = optional(bool)
      monitoring                  = optional(bool)
      enable_volume_tags          = optional(bool)

      # User Data
      user_data                   = optional(string)
      user_data_base64            = optional(string)
      user_data_replace_on_change = optional(bool)

      # Storage Configuration
      cpu_options = optional(object({
        core_count       = optional(number)
        threads_per_core = optional(number)
      }))
      root_block_device = optional(object({
        encrypted             = optional(bool)
        volume_type           = optional(string)
        throughput            = optional(number)
        volume_size           = optional(number)
        iops                  = optional(number)
        delete_on_termination = optional(bool)
        tags                  = optional(map(string))
      }))
      ebs_volumes = optional(map(object({
        device_name           = optional(string)
        volume_size           = optional(number)
        volume_type           = optional(string)
        throughput            = optional(number)
        iops                  = optional(number)
        encrypted             = optional(bool)
        kms_key_id            = optional(string)
        delete_on_termination = optional(bool)
        tags                  = optional(map(string))
      })))

      # Tags
      tags = optional(map(string))
    })
  })
}

variable "environment" {
  description = "An object containing details about the environment."
  type = object({
    name        = string
    unique_name = string
    namespace   = string
    cloud_tags  = optional(map(string), {})
  })
}

variable "instance_name" {
  description = "The architectural name for the resource as added in the Facets blueprint designer."
  type        = string

}

variable "inputs" {
  description = "Inputs dependencies from other modules"
  type = object({
    cloud_account = object({
      aws_iam_role = optional(string)
      aws_region   = optional(string)
      session_name = optional(string)
      external_id  = optional(string)
    })
    network_details = object({
      attributes = object({
        vpc_id             = optional(string)
        vpc_cidr_block     = optional(string)
        public_subnet_ids  = optional(any)
        availability_zones = optional(any)
        private_subnet_ids = optional(any)
      })
    })
  })

}