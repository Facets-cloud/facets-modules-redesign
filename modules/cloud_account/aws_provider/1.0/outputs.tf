locals {
  output_interfaces = {}
  output_attributes = {
    aws_iam_role = sensitive(local.script_output.aws_iam_role)
    session_name = "capillary-cloud-tf-${uuid()}"
    external_id  = sensitive(local.script_output.external_id)
    aws_region   = local.script_output.aws_region
    # Account id parsed from the assumed-role ARN (arn:aws:iam::<id>:role/...).
    # Consumers (kubernetes_cluster, karpenter, kubernetes_node_pool,
    # aws_alb_controller, ack_acm_controller) type cloud_account.attributes with
    # a required aws_account_id, so deriving it here keeps the provider bundle
    # the single source of account identity.
    aws_account_id = try(regex("arn:aws:iam::([0-9]+):", local.script_output.aws_iam_role)[0], null)
    secrets = [
      "external_id"
    ]
  }
}
