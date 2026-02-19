variable "instance_name" {
  type        = string
  description = "Unique architectural name from blueprint"
}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    cloud_tags  = optional(map(string), {})
  })
  description = "Environment context including name and cloud tags"
}

variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    metadata = optional(object({
      name = optional(string, "")
    }), {})
    spec = object({
      encrypted                       = optional(bool, true)
      performance_mode                = optional(string, "generalPurpose")
      throughput_mode                 = optional(string, "bursting")
      provisioned_throughput_in_mibps = optional(number, null)
      kms_key_id                      = optional(string, null)
      availability_zone_name          = optional(string, null)
      lifecycle_policy = optional(object({
        transition_to_ia                    = optional(string, null)
        transition_to_primary_storage_class = optional(string, null)
      }), {})
      tags = optional(map(string), {})
    })
  })
  description = "Instance configuration for the EFS file system"
}

variable "inputs" {
  type = object({
    cloud_account = object({
      attributes = optional(object({
        aws_region   = optional(string)
        aws_iam_role = optional(string)
        external_id  = optional(string)
        session_name = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
    network_details = object({
      attributes = optional(object({
        vpc_id             = optional(string)
        vpc_cidr_block     = optional(string)
        private_subnet_ids = optional(list(string))
      }), {})
      interfaces = optional(object({}), {})
    })
    kubernetes_details = object({
      attributes = optional(object({}), {})
      interfaces = optional(object({}), {})
    })
    csi_driver = object({
      attributes = optional(object({
        iam_role_arn    = optional(string)
        helm_release_id = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
  })
  description = "Inputs from dependent modules"
}
