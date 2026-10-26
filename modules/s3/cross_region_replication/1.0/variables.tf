variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      destination_region        = string
      destination_account_id    = string
      prefix                    = optional(string, "")
      storage_class             = string
      replica_kms_key_id        = optional(string, "")
      delete_marker_replication = bool
    })
  })
}

variable "instance_name" { type = string }

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
    source_bucket = object({
      attributes = optional(object({
        bucket_arn                  = optional(string)
        bucket_domain_name          = optional(string)
        bucket_name                 = optional(string)
        bucket_regional_domain_name = optional(string)
        read_only_iam_policy_arn    = optional(string)
        read_write_iam_policy_arn   = optional(string)
        region                      = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
    destination_bucket = object({
      attributes = optional(object({
        bucket_arn                  = optional(string)
        bucket_domain_name          = optional(string)
        bucket_name                 = optional(string)
        bucket_regional_domain_name = optional(string)
        read_only_iam_policy_arn    = optional(string)
        read_write_iam_policy_arn   = optional(string)
        region                      = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
  })
}
