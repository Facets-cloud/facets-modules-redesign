data "aws_region" "current" {}

locals {
  # Instance spec shortcuts
  spec = var.instance.spec

  # Queue naming - auto-generate from environment and instance name
  # Standard queue: instance-name-environment
  # FIFO queue: instance-name-environment.fifo
  queue_config    = try(local.spec.queue_config, {})
  is_fifo         = try(local.queue_config.fifo_queue, false)
  queue_base_name = "${var.instance_name}-${var.environment.unique_name}"
  queue_name      = local.is_fifo ? "${local.queue_base_name}.fifo" : local.queue_base_name

  # Queue configuration
  visibility_timeout_seconds  = try(local.queue_config.visibility_timeout_seconds, 30)
  message_retention_seconds   = try(local.queue_config.message_retention_seconds, 345600)
  max_message_size            = try(local.queue_config.max_message_size, 262144)
  delay_seconds               = try(local.queue_config.delay_seconds, 0)
  receive_wait_time_seconds   = try(local.queue_config.receive_wait_time_seconds, 0)
  content_based_deduplication = try(local.queue_config.content_based_deduplication, false)

  # Dead Letter Queue configuration
  dlq_config        = try(local.spec.dlq_config, {})
  enable_dlq        = try(local.dlq_config.enable_dlq, false)
  max_receive_count = try(local.dlq_config.max_receive_count, 3)
  dlq_name          = local.is_fifo ? "${local.queue_base_name}-dlq.fifo" : "${local.queue_base_name}-dlq"

  # Encryption configuration
  encryption_config                 = try(local.spec.encryption_config, {})
  enable_encryption                 = try(local.encryption_config.enable_encryption, true)
  kms_key_id                        = try(local.encryption_config.kms_key_id, null)
  kms_data_key_reuse_period_seconds = try(local.encryption_config.kms_data_key_reuse_period_seconds, 300)

  # Use custom KMS key if provided, otherwise use AWS managed key
  kms_master_key_id = local.kms_key_id != null ? local.kms_key_id : (local.enable_encryption ? "alias/aws/sqs" : null)

  # Tags
  custom_tags = try(local.spec.tags, {})

  # Merge environment tags with custom tags
  all_tags = merge(
    var.environment.cloud_tags,
    local.custom_tags,
    {
      Name          = var.instance_name
      resource_type = "sqs_queue"
      flavor        = "standard"
    }
  )
}

# Main SQS Queue
resource "aws_sqs_queue" "main" {
  name                              = local.queue_name
  fifo_queue                        = local.is_fifo
  content_based_deduplication       = local.is_fifo ? local.content_based_deduplication : null
  visibility_timeout_seconds        = local.visibility_timeout_seconds
  message_retention_seconds         = local.message_retention_seconds
  max_message_size                  = local.max_message_size
  delay_seconds                     = local.delay_seconds
  receive_wait_time_seconds         = local.receive_wait_time_seconds
  kms_master_key_id                 = local.kms_master_key_id
  kms_data_key_reuse_period_seconds = local.enable_encryption && local.kms_master_key_id != null ? local.kms_data_key_reuse_period_seconds : null

  # Configure DLQ redrive policy if enabled
  redrive_policy = local.enable_dlq ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[0].arn
    maxReceiveCount     = local.max_receive_count
  }) : null

  tags = local.all_tags
}

# Dead Letter Queue (created only if enabled)
resource "aws_sqs_queue" "dlq" {
  count = local.enable_dlq ? 1 : 0

  name                              = local.dlq_name
  fifo_queue                        = local.is_fifo
  message_retention_seconds         = 1209600 # 14 days retention for DLQ
  kms_master_key_id                 = local.kms_master_key_id
  kms_data_key_reuse_period_seconds = local.enable_encryption && local.kms_master_key_id != null ? local.kms_data_key_reuse_period_seconds : null

  tags = merge(
    local.all_tags,
    {
      Name = "${var.instance_name}-dlq"
    }
  )
}

# IAM Policy for producing (sending) messages
resource "aws_iam_policy" "producer" {
  name        = "${var.instance_name}-${var.environment.unique_name}-sqs-producer"
  description = "Send messages to ${local.queue_name} SQS queue"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.main.arn
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

# IAM Policy for consuming (receiving) messages
resource "aws_iam_policy" "consumer" {
  name        = "${var.instance_name}-${var.environment.unique_name}-sqs-consumer"
  description = "Receive messages from ${local.queue_name} SQS queue"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat([
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = aws_sqs_queue.main.arn
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
