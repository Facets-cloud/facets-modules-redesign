locals {
  output_attributes = {
    arn    = aws_iam_policy.main.arn
    name   = aws_iam_policy.main.name
    policy = aws_iam_policy.main.policy
  }
  output_interfaces = {}
}
