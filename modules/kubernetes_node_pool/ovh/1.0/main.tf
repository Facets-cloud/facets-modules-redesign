# OVH Managed Kubernetes Node Pool Module
# Creates node pools with support for multi-AZ deployments
# Note: Some OVH regions (e.g. BHS5) do not support explicit availability_zones.
# When availability_zones is empty, the parameter is omitted and OVH uses the region default.

locals {
  az_values   = values(var.instance.spec.availability_zones)
  has_az      = length(local.az_values) > 0
  is_multi_az = length(local.az_values) > 1

  node_pools = local.is_multi_az ? {
    for key, az in var.instance.spec.availability_zones : key => {
      name          = "${var.instance_name}-${az.name}"
      az            = az.name
      desired_nodes = ceil(var.instance.spec.desired_nodes / length(local.az_values))
    }
    } : {
    (var.instance_name) = {
      name          = var.instance_name
      az            = local.has_az ? local.az_values[0].name : null
      desired_nodes = var.instance.spec.desired_nodes
    }
  }
}

resource "ovh_cloud_project_kube_nodepool" "pool" {
  for_each     = local.node_pools
  service_name = var.inputs.ovh_provider.attributes.project_id
  kube_id      = var.inputs.kubernetes_cluster.attributes.cluster_id

  name               = each.value.name
  flavor_name        = var.instance.spec.flavor_name
  desired_nodes      = each.value.desired_nodes
  min_nodes          = 1
  max_nodes          = var.instance.spec.max_nodes
  autoscale          = var.instance.spec.autoscale
  monthly_billed     = var.instance.spec.monthly_billed
  availability_zones = each.value.az != null ? [each.value.az] : null

  # Anti-affinity disabled to allow more than 5 nodes
  # OVH limitation: anti-affinity only supports max 5 nodes
  anti_affinity = false

  template {
    metadata {
      annotations = {}
      finalizers  = []
      labels      = { for k, v in var.instance.spec.labels : v.key => v.value }
    }
    spec {
      unschedulable = false
      taints = [
        for key, taint in var.instance.spec.taints : {
          key    = key
          value  = taint.value
          effect = taint.effect
        }
      ]
    }
  }

  lifecycle {
    ignore_changes = [desired_nodes]
  }

  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }
}
