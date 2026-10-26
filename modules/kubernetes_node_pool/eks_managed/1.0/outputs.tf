locals {
  output_attributes = {
    node_class_name = var.instance.spec.node_group_name
    node_pool_name  = var.instance.spec.node_group_name
    taints          = var.instance.spec.taints
    node_selector   = var.instance.spec.labels
  }
  output_interfaces = {}
}
