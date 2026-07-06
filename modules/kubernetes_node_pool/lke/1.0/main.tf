# Linode Kubernetes Engine (LKE) Node Pool Module
# Adds an additional node pool to an existing LKE cluster.

locals {
  autoscaler_enabled = try(var.instance.spec.autoscaler.enabled, false)
  node_selector      = { for k, v in var.instance.spec.labels : v.key => v.value }
  cluster_id         = tonumber(var.inputs.kubernetes_cluster.attributes.cluster_id)
}

resource "linode_lke_node_pool" "pool" {
  cluster_id = local.cluster_id
  type       = var.instance.spec.node_type
  node_count = var.instance.spec.node_count
  tags       = ["facets", var.environment.unique_name, var.instance_name]
  labels     = local.node_selector

  dynamic "autoscaler" {
    for_each = local.autoscaler_enabled ? [1] : []
    content {
      min = var.instance.spec.autoscaler.min
      max = var.instance.spec.autoscaler.max
    }
  }

  dynamic "taint" {
    for_each = var.instance.spec.taints
    content {
      key    = taint.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  lifecycle {
    # When autoscaling is enabled the node count drifts and should not be reconciled.
    ignore_changes = [node_count]
  }
}
