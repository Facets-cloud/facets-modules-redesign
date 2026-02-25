locals {
  output_attributes = {
    aws_region   = var.instance.spec.region
    aws_iam_role = ""
    session_name = ""
    external_id  = ""
  }
  output_interfaces = {}
}
