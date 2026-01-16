locals {
  cluster_name = var.inputs.kubernetes_details.attributes.cluster_name

  # Use values from karpenter_details input (from karpenter controller module)
  node_instance_profile_name = var.inputs.karpenter_details.attributes.node_instance_profile_name
  node_role_arn              = var.inputs.karpenter_details.attributes.node_role_arn
  karpenter_namespace        = var.inputs.karpenter_details.attributes.karpenter_namespace
  karpenter_service_account  = var.inputs.karpenter_details.attributes.karpenter_service_account

  # Merge environment tags with instance tags
  instance_tags = merge(
    var.environment.cloud_tags,
    lookup(var.instance.spec, "tags", {}),
    {
      "facets:instance_name" = var.instance_name
      "facets:environment"   = var.environment.name
      "facets:component"     = "karpenter-nodepool"
    }
  )

  # Output values
  node_class_name = "${var.instance_name}-nodeclass"
  node_pool_name  = "${var.instance_name}-nodepool"
  taints = [
    for taint_key, taint_config in lookup(var.instance.spec, "taints", {}) : {
      key    = taint_key
      value  = taint_config.value
      effect = taint_config.effect
    }
  ]
  labels = lookup(var.instance.spec, "labels", {})
}
