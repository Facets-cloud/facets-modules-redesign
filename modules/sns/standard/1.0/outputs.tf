locals {
  output_attributes = {
    topic_name = aws_sns_topic.main.name
    topic_arn  = aws_sns_topic.main.arn
    region     = data.aws_region.current.name
    is_fifo    = local.is_fifo

    dlq_queue_name = local.enable_dlq ? aws_sqs_queue.dlq[0].name : ""
    dlq_queue_url  = local.enable_dlq ? aws_sqs_queue.dlq[0].url : ""
    dlq_queue_arn  = local.enable_dlq ? aws_sqs_queue.dlq[0].arn : ""

    producer_policy_arn = aws_iam_policy.producer.arn
    consumer_policy_arn = aws_iam_policy.consumer.arn
  }

  output_interfaces = {}
}
