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
      attributes = object({
        aws_region   = string
        aws_iam_role = string
        external_id  = optional(string)
        session_name = optional(string)
      })
    })
    network_details = object({
      attributes = object({
        vpc_id             = string
        vpc_cidr_block     = string
        private_subnet_ids = list(string)
      })
    })
    kubernetes_details = object({
      attributes = optional(object({}))
    })
    csi_driver = object({
      attributes = object({
        iam_role_arn    = string
        helm_release_id = string
      })
    })
  })
  description = "Inputs from dependent modules"
}
