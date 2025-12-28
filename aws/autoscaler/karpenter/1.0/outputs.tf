locals {
  output_attributes = {
    karpenter_namespace        = local.karpenter_namespace
    karpenter_service_account  = local.karpenter_service_account
    karpenter_version          = var.instance.spec.karpenter_version
    controller_role_arn        = aws_iam_role.karpenter_controller.arn
    node_role_arn              = aws_iam_role.karpenter_node.arn
    node_instance_profile_name = aws_iam_instance_profile.karpenter_node.name
    interruption_queue_name    = var.instance.spec.interruption_handling ? aws_sqs_queue.karpenter_interruption[0].name : ""
    secrets                    = []
  }

  output_interfaces = {}
}
