locals {
  output_attributes = {
    queue_name = aws_sqs_queue.main.name
    queue_url  = aws_sqs_queue.main.url
    queue_arn  = aws_sqs_queue.main.arn
    region     = data.aws_region.current.name
    is_fifo    = local.is_fifo

    # Kept for output-type compatibility. 1.1 does not create a child DLQ — a dead-letter queue is
    # another sqs resource, referenced through `redrive.dead_letter_queue_arn` — so these are always
    # empty and exist only so consumers wired against 1.0's contract do not break.
    dlq_queue_name = ""
    dlq_queue_url  = ""
    dlq_queue_arn  = ""

    producer_policy_arn = local.create_iam_policies ? aws_iam_policy.producer[0].arn : ""
    consumer_policy_arn = local.create_iam_policies ? aws_iam_policy.consumer[0].arn : ""
  }

  output_interfaces = {}
}
