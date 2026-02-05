# Name generation modules
module "sns_name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 256
  resource_name   = var.instance_name
  resource_type   = "sns"
  globally_unique = false
  is_k8s          = false
}

module "iam_policy_name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 119
  resource_name   = var.instance_name
  resource_type   = "sns"
  globally_unique = true
  is_k8s          = false
}

# Data sources
data "aws_caller_identity" "current" {}

################################################################################
# SNS Topic
################################################################################

resource "aws_sns_topic" "this" {
  name = local.topic_name

  application_failure_feedback_role_arn    = try(local.application_feedback.failure_role_arn, null)
  application_success_feedback_role_arn    = try(local.application_feedback.success_role_arn, null)
  application_success_feedback_sample_rate = try(local.application_feedback.success_sample_rate, null)

  content_based_deduplication = local.content_based_deduplication
  delivery_policy             = local.delivery_policy
  display_name                = local.display_name != null ? local.display_name : module.sns_name.name
  fifo_topic                  = local.fifo_topic
  signature_version           = local.fifo_topic ? null : local.signature_version
  tracing_config              = local.tracing_config

  firehose_failure_feedback_role_arn    = try(local.firehose_feedback.failure_role_arn, null)
  firehose_success_feedback_role_arn    = try(local.firehose_feedback.success_role_arn, null)
  firehose_success_feedback_sample_rate = try(local.firehose_feedback.success_sample_rate, null)

  http_failure_feedback_role_arn    = try(local.http_feedback.failure_role_arn, null)
  http_success_feedback_role_arn    = try(local.http_feedback.success_role_arn, null)
  http_success_feedback_sample_rate = try(local.http_feedback.success_sample_rate, null)

  kms_master_key_id = local.disable_encryption ? null : local.kms_master_key_id

  lambda_failure_feedback_role_arn    = try(local.lambda_feedback.failure_role_arn, null)
  lambda_success_feedback_role_arn    = try(local.lambda_feedback.success_role_arn, null)
  lambda_success_feedback_sample_rate = try(local.lambda_feedback.success_sample_rate, null)

  policy = local.create_topic_policy ? null : local.topic_policy

  sqs_failure_feedback_role_arn    = try(local.sqs_feedback.failure_role_arn, null)
  sqs_success_feedback_role_arn    = try(local.sqs_feedback.success_role_arn, null)
  sqs_success_feedback_sample_rate = try(local.sqs_feedback.success_sample_rate, null)

  archive_policy = local.archive_policy

  tags = local.cloud_tags
}

################################################################################
# Topic Policy
################################################################################

data "aws_iam_policy_document" "this" {
  count = local.create_topic_policy ? 1 : 0

  source_policy_documents   = local.source_topic_policy_documents
  override_policy_documents = local.create_s3_trigger ? concat([data.aws_iam_policy_document.allow_s3_to_publish[0].json], local.override_topic_policy_documents) : local.override_topic_policy_documents

  dynamic "statement" {
    for_each = local.enable_default_topic_policy ? [1] : []

    content {
      sid = "__default_statement_ID"
      actions = [
        "sns:Subscribe",
        "sns:SetTopicAttributes",
        "sns:RemovePermission",
        "sns:Publish",
        "sns:ListSubscriptionsByTopic",
        "sns:GetTopicAttributes",
        "sns:DeleteTopic",
        "sns:AddPermission",
      ]
      effect    = "Allow"
      resources = [aws_sns_topic.this.arn]

      principals {
        type        = "AWS"
        identifiers = ["*"]
      }

      condition {
        test     = "StringEquals"
        values   = [data.aws_caller_identity.current.account_id]
        variable = "AWS:SourceOwner"
      }
    }
  }

  dynamic "statement" {
    for_each = local.topic_policy_statements

    content {
      sid         = try(statement.value.sid, statement.key)
      actions     = try(statement.value.actions, null)
      not_actions = try(statement.value.not_actions, null)
      effect      = try(statement.value.effect, null)
      # This avoids the chicken vs the egg scenario since its embedded and can reference the topic
      resources     = try(statement.value.resources, [aws_sns_topic.this.arn])
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

resource "aws_sns_topic_policy" "this" {
  count = local.create_topic_policy ? 1 : 0

  arn    = aws_sns_topic.this.arn
  policy = data.aws_iam_policy_document.this[0].json
}

################################################################################
# Subscriptions
################################################################################

resource "aws_sns_topic_subscription" "this" {
  for_each = { for k, v in local.subscriptions : k => v if local.create_subscription }

  confirmation_timeout_in_minutes = try(each.value.confirmation_timeout_in_minutes, null)
  delivery_policy                 = try(each.value.delivery_policy, null)
  endpoint                        = each.value.endpoint
  endpoint_auto_confirms          = try(each.value.endpoint_auto_confirms, null)
  filter_policy                   = try(each.value.filter_policy, null)
  filter_policy_scope             = try(each.value.filter_policy_scope, null)
  protocol                        = each.value.protocol
  raw_message_delivery            = try(each.value.raw_message_delivery, null)
  redrive_policy                  = try(each.value.redrive_policy, null)
  replay_policy                   = try(each.value.replay_policy, null)
  subscription_role_arn           = try(each.value.subscription_role_arn, null)
  topic_arn                       = aws_sns_topic.this.arn
}

################################################################################
# Data Protection Policy
################################################################################

resource "aws_sns_topic_data_protection_policy" "this" {
  count = local.data_protection_policy != null && !local.fifo_topic ? 1 : 0

  arn    = aws_sns_topic.this.arn
  policy = local.data_protection_policy
}

################################################################################
# IAM Policies for Consumer and Producer Access
################################################################################

resource "aws_iam_policy" "consumer_policy" {
  name = "${module.iam_policy_name.name}-consumer"
  tags = local.cloud_tags
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "Stmt1726720504740"
        Action = [
          "sns:GetDataProtectionPolicy",
          "sns:GetEndpointAttributes",
          "sns:GetPlatformApplicationAttributes",
          "sns:GetSMSAttributes",
          "sns:GetSMSSandboxAccountStatus",
          "sns:GetSubscriptionAttributes",
          "sns:GetTopicAttributes",
          "sns:ListEndpointsByPlatformApplication",
          "sns:ListOriginationNumbers",
          "sns:ListPhoneNumbersOptedOut",
          "sns:ListPlatformApplications",
          "sns:ListSMSSandboxPhoneNumbers",
          "sns:ListSubscriptions",
          "sns:ListSubscriptionsByTopic",
          "sns:ListTagsForResource",
          "sns:ListTopics"
        ]
        Effect   = "Allow"
        Resource = aws_sns_topic.this.arn
      }
    ]
  })
}

resource "aws_iam_policy" "producer_policy" {
  name = "${module.iam_policy_name.name}-producer"
  tags = local.cloud_tags
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "Stmt1726721019737"
        Action   = "sns:*"
        Effect   = "Allow"
        Resource = aws_sns_topic.this.arn
      }
    ]
  })
}

################################################################################
# S3 Bucket Notification Trigger
################################################################################

resource "aws_s3_bucket_notification" "bucket_notification" {
  count  = local.create_s3_trigger ? 1 : 0
  bucket = local.s3_name

  topic {
    topic_arn     = aws_sns_topic.this.arn
    events        = local.s3_events
    filter_prefix = local.s3_filter_prefix
    filter_suffix = local.s3_filter_suffix
  }
}

data "aws_iam_policy_document" "allow_s3_to_publish" {
  count = local.create_s3_trigger ? 1 : 0

  statement {
    sid    = "AllowS3ToPublishToSNS"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions   = ["sns:Publish"]
    resources = ["arn:aws:sns:*:*:${module.sns_name.name}"]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [local.s3_arn]
    }
  }

  override_policy_documents = local.override_topic_policy_documents
}
