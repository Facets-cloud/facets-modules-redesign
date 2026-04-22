locals {
  output_attributes = {
    aws_region   = var.instance.spec.aws_region
    aws_iam_role = ""
    session_name = ""
    external_id  = ""
  }
  output_interfaces = {}
}
