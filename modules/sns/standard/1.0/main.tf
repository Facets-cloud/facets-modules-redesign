data "aws_region" "current" {}

locals {
  # Instance spec shortcuts
  spec = var.instance.spec

  # Topic naming - auto-generate from environment and instance name
  # Standard topic: instance-name-environment
  # FIFO topic: instance-name-environment.fifo
  topic_config                = try(local.spec.topic_config, {})
  is_fifo                     = try(local.topic_config.fifo_topic, false)
  topic_base_name             = "${var.instance_name}-${var.environment.unique_name}"
  topic_name                  = local.is_fifo ? "${local.topic_base_name}.fifo" : local.topic_base_name
  display_name                = try(local.topic_config.display_name, var.instance_name)
  content_based_deduplication = try(local.topic_config.content_based_deduplication, false)

  # Dead Letter Queue configuration for failed deliveries
  dlq_config = try(local.spec.dlq_config, {})
  enable_dlq = try(local.dlq_config.enable_dlq, false)
  dlq_name   = local.is_fifo ? "${local.topic_base_name}-dlq.fifo" : "${local.topic_base_name}-dlq"

  # Encryption configuration
  encryption_config = try(local.spec.encryption_config, {})
  enable_encryption = try(local.encryption_config.enable_encryption, true)
  kms_key_id        = try(local.encryption_config.kms_key_id, null)

  # Use custom KMS key if provided, otherwise use AWS managed key
  kms_master_key_id = local.kms_key_id != null ? local.kms_key_id : (local.enable_encryption ? "alias/aws/sns" : null)

  # Tags
  custom_tags = try(local.spec.tags, {})

  # Merge environment tags with custom tags
  all_tags = merge(
    var.environment.cloud_tags,
    local.custom_tags,
    {
      Name          = var.instance_name
      resource_type = "sns_topic"
      flavor        = "standard"
    }
  )
}

# SNS Topic
resource "aws_sns_topic" "main" {
  name                        = local.topic_name
  display_name                = local.display_name
  fifo_topic                  = local.is_fifo
  content_based_deduplication = local.is_fifo ? local.content_based_deduplication : null
  kms_master_key_id           = local.kms_master_key_id

  tags = local.all_tags
}

# Dead Letter Queue for failed message deliveries (SQS)
resource "aws_sqs_queue" "dlq" {
  count = local.enable_dlq ? 1 : 0

  name                              = local.dlq_name
  fifo_queue                        = local.is_fifo
  message_retention_seconds         = 1209600 # 14 days retention for DLQ
  kms_master_key_id                 = local.kms_master_key_id != null ? (local.kms_key_id != null ? local.kms_key_id : "alias/aws/sqs") : null
  kms_data_key_reuse_period_seconds = local.enable_encryption && local.kms_key_id != null ? 300 : null

  tags = merge(
    local.all_tags,
    {
      Name = "${var.instance_name}-dlq"
    }
  )
}

# SQS Queue Policy to allow SNS to send messages to DLQ
resource "aws_sqs_queue_policy" "dlq" {
  count = local.enable_dlq ? 1 : 0

  queue_url = aws_sqs_queue.dlq[0].url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.dlq[0].arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.main.arn
          }
        }
      }
    ]
  })
}

# IAM Policy for producing (publishing) messages
resource "aws_iam_policy" "producer" {
  name        = "${var.instance_name}-${var.environment.unique_name}-sns-producer"
  description = "Publish messages to ${local.topic_name} SNS topic"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "sns:Publish",
          "sns:GetTopicAttributes"
        ]
        Resource = aws_sns_topic.main.arn
      }
      ],
      local.kms_key_id != null ? [{
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = local.kms_key_id
      }] : []
    )
  })
  tags = local.all_tags
}

# IAM Policy for consuming (subscribing to) messages
resource "aws_iam_policy" "consumer" {
  name        = "${var.instance_name}-${var.environment.unique_name}-sns-consumer"
  description = "Subscribe to ${local.topic_name} SNS topic"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "sns:Subscribe",
          "sns:Unsubscribe",
          "sns:GetTopicAttributes",
          "sns:GetSubscriptionAttributes",
          "sns:SetSubscriptionAttributes"
        ]
        Resource = aws_sns_topic.main.arn
      }
      ],
      local.kms_key_id != null ? [{
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = local.kms_key_id
      }] : []
    )
  })
  tags = local.all_tags
}
