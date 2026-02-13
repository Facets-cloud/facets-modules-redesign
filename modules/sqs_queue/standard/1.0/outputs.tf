locals {
  # Build outputs from created queue resource
  output_attributes = {
    queue_name = aws_sqs_queue.main.name
    queue_url  = aws_sqs_queue.main.url
    queue_arn  = aws_sqs_queue.main.arn

    # AWS account and region information
    region     = data.aws_region.current.name
    account_id = data.aws_caller_identity.current.account_id

    # Queue configuration details
    is_fifo = local.is_fifo

    # DLQ details (empty strings if DLQ not enabled)
    dlq_queue_name = local.enable_dlq ? aws_sqs_queue.dlq[0].name : ""
    dlq_queue_url  = local.enable_dlq ? aws_sqs_queue.dlq[0].url : ""
    dlq_queue_arn  = local.enable_dlq ? aws_sqs_queue.dlq[0].arn : ""

    # IAM policies for IRSA
    send_policy_arn         = aws_iam_policy.send.arn
    receive_policy_arn      = aws_iam_policy.receive.arn
    full_access_policy_arn  = aws_iam_policy.full_access.arn
    send_policy_name        = aws_iam_policy.send.name
    receive_policy_name     = aws_iam_policy.receive.name
    full_access_policy_name = aws_iam_policy.full_access.name
  }

  output_interfaces = {
    queue = {
      name = aws_sqs_queue.main.name
      url  = aws_sqs_queue.main.url
      arn  = aws_sqs_queue.main.arn
    }
    dlq = local.enable_dlq ? {
      name = aws_sqs_queue.dlq[0].name
      url  = aws_sqs_queue.dlq[0].url
      arn  = aws_sqs_queue.dlq[0].arn
    } : null
  }
}
