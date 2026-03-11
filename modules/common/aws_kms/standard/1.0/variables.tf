variable "instance" {
  type = object({
    kind    = string
    flavor  = string
    version = string
    spec = optional(object({
      create_external                        = optional(bool, false)
      bypass_policy_lockout_safety_check     = optional(bool)
      customer_master_key_spec               = optional(string)
      custom_key_store_id                    = optional(string)
      description                            = optional(string)
      enable_key_rotation                    = optional(bool, true)
      deletion_window_in_days                = optional(number, 30)
      is_enabled                             = optional(bool, true)
      key_material_base64                    = optional(string)
      key_usage                              = optional(string)
      multi_region                           = optional(bool, false)
      policy                                 = optional(string)
      valid_to                               = optional(string)
      enable_default_policy                  = optional(bool, true)
      key_owners                             = optional(list(string), [])
      key_administrators                     = optional(list(string), [])
      key_users                              = optional(list(string), [])
      key_service_users                      = optional(list(string), [])
      key_service_roles_for_autoscaling      = optional(list(string), [])
      key_symmetric_encryption_users         = optional(list(string), [])
      key_hmac_users                         = optional(list(string), [])
      key_asymmetric_public_encryption_users = optional(list(string), [])
      key_asymmetric_sign_verify_users       = optional(list(string), [])
      key_statements = optional(list(object({
        sid           = optional(string)
        actions       = optional(list(string))
        not_actions   = optional(list(string))
        effect        = optional(string)
        resources     = optional(list(string))
        not_resources = optional(list(string))
        principals = optional(list(object({
          type        = string
          identifiers = list(string)
        })))
        not_principals = optional(list(object({
          type        = string
          identifiers = list(string)
        })))
        condition = optional(list(object({
          test     = string
          values   = list(string)
          variable = string
        })))
      })))
      source_policy_documents   = optional(list(string), [])
      override_policy_documents = optional(list(string), [])
      enable_route53_dnssec     = optional(bool, false)
      route53_dnssec_sources = optional(list(object({
        account_ids     = optional(list(string))
        hosted_zone_arn = optional(string)
      })))
      rotation_period_in_days  = optional(number, 90)
      create_replica           = optional(bool, false)
      primary_key_arn          = optional(string)
      create_replica_external  = optional(bool, false)
      primary_external_key_arn = optional(string)
      aliases                  = optional(list(string), [])
      computed_aliases = optional(map(object({
        name = string
      })), {})
      aliases_use_name_prefix = optional(bool, false)
      grants = optional(map(object({
        constraints = optional(list(object({
          encryption_context_equals = optional(map(string))
          encryption_context_subset = optional(map(string))
        })))
        grant_creation_tokens = optional(list(string))
        grantee_principal     = string
        name                  = optional(string)
        operations            = list(string)
        retire_on_delete      = optional(bool)
        retiring_principal    = optional(string)
      })))
      tags = optional(map(string), {})
    }), {})
  })
}


variable "instance_name" {
  type        = string
  description = "Unique architectural name from blueprint"


}

variable "environment" {
  type = object({
    name        = string
    unique_name = string
    namespace   = string
    region      = string
    cloud_tags  = optional(map(string), {})
  })
}


variable "inputs" {
  description = "Input dependency from other modules"
  type = object({
    cloud_account = object({
      attributes = object({
        aws_iam_role = string
        session_name = string
        external_id  = string
        aws_region   = string
      })
    })
  })

}

