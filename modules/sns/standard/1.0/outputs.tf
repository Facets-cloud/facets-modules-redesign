locals {
  output_attributes = {
    topic_arn            = aws_sns_topic.main.arn
    topic_name           = aws_sns_topic.main.name
    topic_id             = aws_sns_topic.main.id
    display_name         = aws_sns_topic.main.display_name
    region               = data.aws_region.current.name
    subscription_count   = tostring(length(local.subscriptions))
    publisher_policy_arn = local.create_iam_policies ? aws_iam_policy.publisher[0].arn : ""
  }
  output_interfaces = {}
}
