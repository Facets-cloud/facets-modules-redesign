locals {
  output_interfaces = {}
  output_attributes = {
    aws_iam_role = sensitive(local.script_output.aws_iam_role)
    # Account ID is part of the role ARN (arn:aws:iam::<account>:role/<name>); not a secret.
    # null (not a plan failure) if an older account stored something other than an ARN.
    aws_account_id = try(split(":", local.script_output.aws_iam_role)[4], null)
    session_name   = "capillary-cloud-tf-${uuid()}"
    external_id    = sensitive(local.script_output.external_id)
    aws_region     = local.script_output.aws_region
    secrets = [
      "external_id"
    ]
  }
}
