locals {
  output_attributes = {
    iam_role_arn                  = aws_iam_role.this.arn
    iam_role_name                 = aws_iam_role.this.name
    gcp_service_account_email     = local.gcp_service_account_email
    gcp_service_account_unique_id = local.gcp_service_account_unique_id
  }

  output_interfaces = {}
}
