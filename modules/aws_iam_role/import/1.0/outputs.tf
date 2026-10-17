locals {
  output_attributes = {
    iam_role_arn      = aws_iam_role.main.arn
    iam_role_name     = aws_iam_role.main.name
    irsa_iam_role_arn = aws_iam_role.main.arn
  }
  output_interfaces = {}
}
