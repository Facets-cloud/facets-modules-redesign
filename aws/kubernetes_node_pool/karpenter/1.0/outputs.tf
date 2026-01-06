locals {
  output_attributes = {
    # Karpenter controller details
    karpenter_namespace       = local.karpenter_namespace
    karpenter_service_account = local.karpenter_service_account
    karpenter_version         = var.instance.spec.karpenter_version

    # IAM details - use created resources when install_karpenter is true, otherwise use input values
    controller_role_arn        = local.install_karpenter ? aws_iam_role.karpenter_controller[0].arn : try(var.inputs.karpenter_details.attributes.controller_role_arn, "")
    node_role_arn              = local.node_role_arn
    node_instance_profile_name = local.node_instance_profile_name

    # Interruption handling
    interruption_queue_name = local.install_karpenter && var.instance.spec.interruption_handling ? aws_sqs_queue.karpenter_interruption[0].name : ""

    # NodePool details for this instance
    nodepool_name  = "${var.instance_name}-nodepool"
    nodeclass_name = "${var.instance_name}-nodeclass"

    # Taints configured for this node pool (use this in your service/deployment tolerations)
    taints = [
      for taint_key, taint_config in lookup(var.instance.spec, "taints", {}) : {
        key    = taint_key
        value  = taint_config.value
        effect = taint_config.effect
      }
    ]

    # Labels configured for this node pool (use this in your service/deployment nodeSelectors)
    labels = lookup(var.instance.spec, "labels", {})

    secrets = []
  }

  output_interfaces = {}
}
