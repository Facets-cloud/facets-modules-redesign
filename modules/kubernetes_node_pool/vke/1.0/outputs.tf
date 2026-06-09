locals {
  # Built in a local (not inline) so the output_attributes block stays free of
  # for-comprehensions, which the contract validator's HCL parser cannot descend into.
  taints_out = [
    for key, taint in var.instance.spec.taints : {
      key    = key
      value  = taint.value
      effect = taint.effect
    }
  ]

  output_attributes = {
    node_pool_name  = tostring(vultr_kubernetes_node_pools.pool.id)
    node_class_name = module.name.name
    taints          = local.taints_out
    node_selector   = local.node_selector
  }

  output_interfaces = {}
}
