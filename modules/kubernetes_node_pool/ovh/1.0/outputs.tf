locals {
  pool_names = [for k, v in ovh_cloud_project_kube_nodepool.pool : v.name]

  output_attributes = {
    node_pool_name = join(",", local.pool_names)
    taints = [
      for key, taint in var.instance.spec.taints : {
        key    = key
        value  = taint.value
        effect = taint.effect
      }
    ]
    node_selector = { for k, v in var.instance.spec.labels : v.key => v.value }
  }

  output_interfaces = {}
}
