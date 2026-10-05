locals {
  output_attributes = {
    table_name = aws_dynamodb_table.main.name
    table_arn  = aws_dynamodb_table.main.arn
    table_id   = aws_dynamodb_table.main.id
  }
  output_interfaces = {}
}
