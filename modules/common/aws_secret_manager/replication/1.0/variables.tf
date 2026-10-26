variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = object({
      replica_regions                = list(string)
      replica_kms_key_ids            = optional(map(string), {})
      force_overwrite_replica_secret = optional(bool, false)
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
    source_secret = object({
      attributes = optional(object({
        secret_name         = optional(string)
        secret_id           = optional(string)
        secret_arn          = optional(string)
        secret_version_arn  = optional(string)
        secret_version_id   = optional(string)
        rotation_enabled    = optional(bool)
        rotation_lambda_arn = optional(string)
      }), {})
      interfaces = optional(object({}), {})
    })
  })
}
