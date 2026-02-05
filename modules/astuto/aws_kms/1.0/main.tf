# Data sources
data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition
  dns_suffix = data.aws_partition.current.dns_suffix
}

################################################################################
# Standard KMS Key
################################################################################

resource "aws_kms_key" "this" {
  count = !local.create_external && !local.create_replica && !local.create_replica_external ? 1 : 0

  bypass_policy_lockout_safety_check = local.bypass_policy_lockout_safety_check
  customer_master_key_spec           = local.customer_master_key_spec
  custom_key_store_id                = local.custom_key_store_id
  deletion_window_in_days            = local.deletion_window_in_days
  description                        = local.description
  enable_key_rotation                = local.enable_key_rotation
  is_enabled                         = local.is_enabled
  key_usage                          = local.key_usage
  multi_region                       = local.multi_region
  policy                             = coalesce(local.policy, data.aws_iam_policy_document.this.json)
  rotation_period_in_days            = local.rotation_period_in_days

  tags = local.tags
}

################################################################################
# External KMS Key
################################################################################

resource "aws_kms_external_key" "this" {
  count = local.create_external && !local.create_replica && !local.create_replica_external ? 1 : 0

  bypass_policy_lockout_safety_check = local.bypass_policy_lockout_safety_check
  deletion_window_in_days            = local.deletion_window_in_days
  description                        = local.description
  enabled                            = local.is_enabled
  key_material_base64                = local.key_material_base64
  multi_region                       = local.multi_region
  policy                             = coalesce(local.policy, data.aws_iam_policy_document.this.json)
  valid_to                           = local.valid_to

  tags = local.tags
}

################################################################################
# Replica KMS Key
################################################################################

resource "aws_kms_replica_key" "this" {
  count = local.create_replica && !local.create_external && !local.create_replica_external ? 1 : 0

  bypass_policy_lockout_safety_check = local.bypass_policy_lockout_safety_check
  deletion_window_in_days            = local.deletion_window_in_days
  description                        = local.description
  primary_key_arn                    = local.primary_key_arn
  enabled                            = local.is_enabled
  policy                             = coalesce(local.policy, data.aws_iam_policy_document.this.json)

  tags = local.tags
}

################################################################################
# Replica External KMS Key
################################################################################

resource "aws_kms_replica_external_key" "this" {
  count = !local.create_replica && !local.create_external && local.create_replica_external ? 1 : 0

  bypass_policy_lockout_safety_check = local.bypass_policy_lockout_safety_check
  deletion_window_in_days            = local.deletion_window_in_days
  description                        = local.description
  enabled                            = local.is_enabled
  key_material_base64                = local.key_material_base64
  policy                             = coalesce(local.policy, data.aws_iam_policy_document.this.json)
  primary_key_arn                    = local.primary_external_key_arn
  valid_to                           = local.valid_to

  tags = local.tags
}

################################################################################
# Key Policy
################################################################################

data "aws_iam_policy_document" "this" {
  source_policy_documents   = local.source_policy_documents
  override_policy_documents = local.override_policy_documents

  # Default policy - account wide access to all key operations
  dynamic "statement" {
    for_each = local.enable_default_policy ? [1] : []

    content {
      sid       = "Default"
      actions   = ["kms:*"]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = ["arn:${local.partition}:iam::${local.account_id}:root"]
      }
    }
  }

  # Key owner - all key operations
  dynamic "statement" {
    for_each = length(local.key_owners) > 0 ? [1] : []

    content {
      sid       = "KeyOwner"
      actions   = ["kms:*"]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = local.key_owners
      }
    }
  }

  # Key administrators
  dynamic "statement" {
    for_each = length(local.key_administrators) > 0 ? [1] : []

    content {
      sid = "KeyAdministration"
      actions = [
        "kms:Create*",
        "kms:Describe*",
        "kms:Enable*",
        "kms:List*",
        "kms:Put*",
        "kms:Update*",
        "kms:Revoke*",
        "kms:Disable*",
        "kms:Get*",
        "kms:Delete*",
        "kms:TagResource",
        "kms:UntagResource",
        "kms:ScheduleKeyDeletion",
        "kms:CancelKeyDeletion",
        "kms:ReplicateKey",
        "kms:ImportKeyMaterial"
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = local.key_administrators
      }
    }
  }

  # Key users
  dynamic "statement" {
    for_each = length(local.key_users) > 0 ? [1] : []

    content {
      sid = "KeyUsage"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = local.key_users
      }
    }
  }

  # Key service users
  dynamic "statement" {
    for_each = length(local.key_service_users) > 0 ? [1] : []

    content {
      sid = "KeyServiceUsage"
      actions = [
        "kms:CreateGrant",
        "kms:ListGrants",
        "kms:RevokeGrant",
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = local.key_service_users
      }

      condition {
        test     = "Bool"
        variable = "kms:GrantIsForAWSResource"
        values   = [true]
      }
    }
  }

  # Key service roles for autoscaling
  dynamic "statement" {
    for_each = length(local.key_service_roles_for_autoscaling) > 0 ? [1] : []

    content {
      sid = "KeyServiceRolesASG"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = local.key_service_roles_for_autoscaling
      }
    }
  }

  dynamic "statement" {
    for_each = length(local.key_service_roles_for_autoscaling) > 0 ? [1] : []

    content {
      sid = "KeyServiceRolesASGPersistentVol"
      actions = [
        "kms:CreateGrant"
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = local.key_service_roles_for_autoscaling
      }

      condition {
        test     = "Bool"
        variable = "kms:GrantIsForAWSResource"
        values   = [true]
      }
    }
  }

  # Symmetric encryption users
  dynamic "statement" {
    for_each = length(local.key_symmetric_encryption_users) > 0 ? [1] : []

    content {
      sid = "KeySymmetricEncryption"
      actions = [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:Encrypt",
        "kms:GenerateDataKey*",
        "kms:ReEncrypt*",
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = local.key_symmetric_encryption_users
      }
    }
  }

  # HMAC users
  dynamic "statement" {
    for_each = length(local.key_hmac_users) > 0 ? [1] : []

    content {
      sid = "KeyHMAC"
      actions = [
        "kms:DescribeKey",
        "kms:GenerateMac",
        "kms:VerifyMac",
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = local.key_hmac_users
      }
    }
  }

  # Asymmetric public encryption users
  dynamic "statement" {
    for_each = length(local.key_asymmetric_public_encryption_users) > 0 ? [1] : []

    content {
      sid = "KeyAsymmetricPublicEncryption"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:DescribeKey",
        "kms:GetPublicKey",
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = local.key_asymmetric_public_encryption_users
      }
    }
  }

  # Asymmetric sign/verify users
  dynamic "statement" {
    for_each = length(local.key_asymmetric_sign_verify_users) > 0 ? [1] : []

    content {
      sid = "KeyAsymmetricSignVerify"
      actions = [
        "kms:DescribeKey",
        "kms:GetPublicKey",
        "kms:Sign",
        "kms:Verify",
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = local.key_asymmetric_sign_verify_users
      }
    }
  }

  # Route53 DNSSEC service
  dynamic "statement" {
    for_each = local.enable_route53_dnssec ? [1] : []

    content {
      sid = "Route53DnssecService"
      actions = [
        "kms:DescribeKey",
        "kms:GetPublicKey",
        "kms:Sign",
      ]
      resources = ["*"]

      principals {
        type        = "Service"
        identifiers = ["dnssec-route53.${local.dns_suffix}"]
      }
    }
  }

  # Route53 DNSSEC grant
  dynamic "statement" {
    for_each = local.enable_route53_dnssec ? [1] : []

    content {
      sid       = "Route53DnssecGrant"
      actions   = ["kms:CreateGrant"]
      resources = ["*"]

      principals {
        type        = "Service"
        identifiers = ["dnssec-route53.${local.dns_suffix}"]
      }

      condition {
        test     = "Bool"
        variable = "kms:GrantIsForAWSResource"
        values   = ["true"]
      }

      dynamic "condition" {
        for_each = local.route53_dnssec_sources

        content {
          test     = "StringEquals"
          variable = "aws:SourceAccount"
          values   = try(condition.value.account_ids, [local.account_id])
        }
      }

      dynamic "condition" {
        for_each = local.route53_dnssec_sources

        content {
          test     = "ArnLike"
          variable = "aws:SourceArn"
          values   = [try(condition.value.hosted_zone_arn, "arn:${local.partition}:route53:::hostedzone/*")]
        }
      }
    }
  }

  # Custom key statements
  dynamic "statement" {
    for_each = local.key_statements

    content {
      sid           = try(statement.value.sid, null)
      actions       = try(statement.value.actions, null)
      not_actions   = try(statement.value.not_actions, null)
      effect        = try(statement.value.effect, null)
      resources     = try(statement.value.resources, null)
      not_resources = try(statement.value.not_resources, null)

      dynamic "principals" {
        for_each = try(statement.value.principals, [])

        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }

      dynamic "not_principals" {
        for_each = try(statement.value.not_principals, [])

        content {
          type        = not_principals.value.type
          identifiers = not_principals.value.identifiers
        }
      }

      dynamic "condition" {
        for_each = try(statement.value.conditions, [])

        content {
          test     = condition.value.test
          values   = condition.value.values
          variable = condition.value.variable
        }
      }
    }
  }
}

################################################################################
# Key Aliases
################################################################################

locals {
  aliases_list = { for k, v in toset(local.aliases) : k => { name = v } }
}

resource "aws_kms_alias" "this" {
  for_each = merge(local.aliases_list, local.computed_aliases)

  name          = local.aliases_use_name_prefix ? null : "alias/${each.value.name}"
  name_prefix   = local.aliases_use_name_prefix ? "alias/${each.value.name}-" : null
  target_key_id = try(aws_kms_key.this[0].key_id, aws_kms_external_key.this[0].id, aws_kms_replica_key.this[0].key_id, aws_kms_replica_external_key.this[0].key_id)
}

################################################################################
# Key Grants
################################################################################

resource "aws_kms_grant" "this" {
  for_each = local.grants

  name              = try(each.value.name, each.key)
  key_id            = try(aws_kms_key.this[0].key_id, aws_kms_external_key.this[0].id, aws_kms_replica_key.this[0].key_id, aws_kms_replica_external_key.this[0].key_id)
  grantee_principal = each.value.grantee_principal
  operations        = each.value.operations

  dynamic "constraints" {
    for_each = length(lookup(each.value, "constraints", {})) == 0 ? [] : [each.value.constraints]

    content {
      encryption_context_equals = try(constraints.value.encryption_context_equals, null)
      encryption_context_subset = try(constraints.value.encryption_context_subset, null)
    }
  }

  retiring_principal    = try(each.value.retiring_principal, null)
  grant_creation_tokens = try(each.value.grant_creation_tokens, null)
  retire_on_delete      = try(each.value.retire_on_delete, null)
}
