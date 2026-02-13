locals {
  # Build outputs from created topic resource
  output_attributes = {
    topic_name = aws_sns_topic.main.name
    topic_arn  = aws_sns_topic.main.arn

    # AWS account and region information
    region     = data.aws_region.current.name
    account_id = data.aws_caller_identity.current.account_id

    # Topic configuration details
    is_fifo = local.is_fifo

    # DLQ details (empty strings if DLQ not enabled)
    dlq_queue_name = local.enable_dlq ? aws_sqs_queue.dlq[0].name : ""
    dlq_queue_url  = local.enable_dlq ? aws_sqs_queue.dlq[0].url : ""
    dlq_queue_arn  = local.enable_dlq ? aws_sqs_queue.dlq[0].arn : ""

    # IAM policies for IRSA
    publish_policy_arn      = aws_iam_policy.publish.arn
    subscribe_policy_arn    = aws_iam_policy.subscribe.arn
    full_access_policy_arn  = aws_iam_policy.full_access.arn
    publish_policy_name     = aws_iam_policy.publish.name
    subscribe_policy_name   = aws_iam_policy.subscribe.name
    full_access_policy_name = aws_iam_policy.full_access.name
  }

  output_interfaces = {
    topic = {
      name = aws_sns_topic.main.name
      arn  = aws_sns_topic.main.arn
    }
    dlq = local.enable_dlq ? {
      name = aws_sqs_queue.dlq[0].name
      url  = aws_sqs_queue.dlq[0].url
      arn  = aws_sqs_queue.dlq[0].arn
    } : null
  }
}
