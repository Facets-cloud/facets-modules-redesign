locals {
  output_attributes = {
    name = aws_cloudwatch_log_group.main.name
    arn  = aws_cloudwatch_log_group.main.arn
  }
  output_interfaces = {}
}
