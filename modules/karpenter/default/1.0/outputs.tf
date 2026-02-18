locals {
  output_attributes = {
    # Karpenter controller details
    karpenter_namespace       = local.karpenter_namespace
    karpenter_service_account = local.karpenter_service_account
    karpenter_version         = var.instance.spec.karpenter_version

    # IAM details
    controller_role_arn        = aws_iam_role.karpenter_controller.arn
    node_role_arn              = aws_iam_role.karpenter_node.arn
    node_instance_profile_name = aws_iam_instance_profile.karpenter_node.name

    # Interruption handling
    interruption_queue_name = local.interruption_handling_enabled ? aws_sqs_queue.karpenter_interruption[0].name : ""

    helm_release_id = helm_release.karpenter.id

    secrets = []
  }

  output_interfaces = {}
}
