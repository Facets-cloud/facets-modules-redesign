# Name generation module
module "sqs_name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 80
  resource_name   = var.instance_name
  resource_type   = "sqs"
  globally_unique = false
  is_k8s          = false
}

module "iam_policy_name" {
  source          = "github.com/Facets-cloud/facets-utility-modules//name"
  environment     = var.environment
  limit           = 119
  resource_name   = var.instance_name
  resource_type   = "sqs"
  globally_unique = true
  is_k8s          = false
}

################################################################################
# SQS Queue
################################################################################

resource "aws_sqs_queue" "this" {
  name = local.queue_name

  visibility_timeout_seconds  = local.visibility_timeout_seconds
  message_retention_seconds   = local.message_retention_seconds
  max_message_size            = local.max_message_size
  delay_seconds               = local.delay_seconds
  receive_wait_time_seconds   = local.receive_wait_time_seconds
  redrive_policy              = local.redrive_policy != "" ? local.redrive_policy : null
  fifo_queue                  = local.fifo_queue
  content_based_deduplication = local.content_based_deduplication

  sqs_managed_sse_enabled           = local.use_sqs_managed_sse ? true : null
  kms_master_key_id                 = local.use_sqs_managed_sse ? null : local.kms_master_key_id
  kms_data_key_reuse_period_seconds = local.kms_data_key_reuse_period_seconds

  tags = local.cloud_tags
}

################################################################################
# Queue Policy
################################################################################

data "aws_iam_policy_document" "sqs_policies" {
  override_policy_documents = [local.policy]

  # Allow SNS to publish to this queue
  statement {
    sid    = "AllowSNSToPublishToQueue"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }
    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.this.arn]
  }

  # Allow EventBridge to send messages to this queue
  statement {
    sid     = "events-policy"
    effect  = "Allow"
    actions = ["sqs:SendMessage"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    resources = [aws_sqs_queue.this.arn]
  }
}

resource "aws_sqs_queue_policy" "sqs_queue_policies" {
  queue_url = aws_sqs_queue.this.id
  policy    = data.aws_iam_policy_document.sqs_policies.json
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
        Effect = "Allow"
        Action = [
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage*",
          "sqs:PurgeQueue",
          "sqs:ChangeMessageVisibility*"
        ]
        Resource = [aws_sqs_queue.this.arn]
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
        Effect = "Allow"
        Action = [
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",
          "sqs:SendMessage*"
        ]
        Resource = [aws_sqs_queue.this.arn]
      }
    ]
  })
}
