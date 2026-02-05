# Extract spec and advanced configuration
locals {
  advanced_config = lookup(lookup(var.instance, "advanced", {}), "sqs", {})
  spec_config     = lookup(var.instance, "spec", {})
  metadata        = lookup(var.instance, "metadata", {})
  cloud_tags      = merge(lookup(local.metadata, "tags", {}), var.environment.cloud_tags)

  # SQS queue configuration
  visibility_timeout_seconds = lookup(local.spec_config, "visibility_timeout_seconds", lookup(local.advanced_config, "visibility_timeout_seconds", 30))
  message_retention_seconds  = lookup(local.spec_config, "message_retention_seconds", lookup(local.advanced_config, "message_retention_seconds", 345600))
  max_message_size           = lookup(local.spec_config, "max_message_size", lookup(local.advanced_config, "max_message_size", 5120))
  delay_seconds              = lookup(local.spec_config, "delay_seconds", lookup(local.advanced_config, "delay_seconds", 60))
  receive_wait_time_seconds  = lookup(local.spec_config, "receive_wait_time_seconds", lookup(local.advanced_config, "receive_wait_time_seconds", 10))

  # FIFO and deduplication
  fifo_queue                  = lookup(local.spec_config, "fifo_queue", lookup(local.advanced_config, "fifo_queue", false))
  content_based_deduplication = lookup(local.spec_config, "content_based_deduplication", lookup(local.advanced_config, "content_based_deduplication", false))

  # Encryption
  use_sqs_managed_sse               = lookup(local.spec_config, "use_sqs_managed_sse", false)
  kms_master_key_id                 = lookup(local.spec_config, "kms_master_key_id", lookup(local.advanced_config, "kms_master_key_id", "alias/aws/sqs"))
  kms_data_key_reuse_period_seconds = lookup(local.spec_config, "kms_data_key_reuse_period_seconds", lookup(local.advanced_config, "kms_data_key_reuse_period_seconds", 300))

  # Policy
  policy = jsonencode(lookup(local.spec_config, "policy", lookup(local.advanced_config, "policy", {})))

  # Dead letter queue
  dead_letter_queue = lookup(local.spec_config, "dead_letter_queue", null)
  redrive_policy = local.dead_letter_queue == null ? lookup(local.advanced_config, "redrive_policy", "") : jsonencode({
    deadLetterTargetArn = lookup(local.dead_letter_queue, "deadLetterTargetArn", null)
    maxReceiveCount     = lookup(local.dead_letter_queue, "maxReceiveCount", null)
  })

  # Queue name (add .fifo suffix for FIFO queues)
  queue_name = local.fifo_queue ? "${module.sqs_name.name}.fifo" : module.sqs_name.name
}

# Output attributes and interfaces
locals {
  output_attributes = {
    sqs_queue_name      = aws_sqs_queue.this.name
    queue_arn           = aws_sqs_queue.this.arn
    queue_url           = aws_sqs_queue.this.id
    consumer_policy_arn = aws_iam_policy.consumer_policy.arn
    producer_policy_arn = aws_iam_policy.producer_policy.arn
  }

  output_interfaces = {}
}
