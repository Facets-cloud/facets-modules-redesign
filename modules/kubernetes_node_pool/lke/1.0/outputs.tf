locals {
  output_attributes = {
    node_pool_name = tostring(linode_lke_node_pool.pool.id)
    taints = [
      for key, taint in var.instance.spec.taints : {
        key    = key
        value  = taint.value
        effect = taint.effect
      }
    ]
    node_selector = local.node_selector
  }

  output_interfaces = {}
}
