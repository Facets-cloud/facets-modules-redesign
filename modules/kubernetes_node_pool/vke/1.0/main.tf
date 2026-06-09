# Vultr Kubernetes Engine (VKE) Node Pool Module
# Adds an additional node pool to an existing VKE cluster.

locals {
  autoscaler_enabled = try(var.instance.spec.autoscaler.enabled, false)
  node_selector      = { for k, v in var.instance.spec.labels : v.key => v.value }
  # Vultr cluster IDs are UUID strings (no numeric conversion needed).
  cluster_id = var.inputs.kubernetes_cluster.attributes.cluster_id
}

module "name" {
  source        = "github.com/Facets-cloud/facets-utility-modules//name"
  environment   = var.environment
  limit         = 32
  resource_name = var.instance_name
  resource_type = "nodepool"
}

resource "vultr_kubernetes_node_pools" "pool" {
  cluster_id    = local.cluster_id
  label         = module.name.name
  plan          = var.instance.spec.node_type
  node_quantity = var.instance.spec.node_count
  tag           = var.instance_name
  auto_scaler   = local.autoscaler_enabled
  min_nodes     = local.autoscaler_enabled ? var.instance.spec.autoscaler.min : null
  max_nodes     = local.autoscaler_enabled ? var.instance.spec.autoscaler.max : null

  dynamic "labels" {
    for_each = var.instance.spec.labels
    content {
      key   = labels.value.key
      value = labels.value.value
    }
  }

  dynamic "taints" {
    for_each = var.instance.spec.taints
    content {
      key    = taints.key
      value  = taints.value.value
      effect = taints.value.effect
    }
  }

  lifecycle {
    # When autoscaling is enabled the node count drifts and should not be reconciled.
    ignore_changes = [node_quantity]
  }
}
