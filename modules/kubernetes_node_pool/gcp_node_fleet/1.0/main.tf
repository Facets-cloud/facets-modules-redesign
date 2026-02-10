module "gke-node-fleet" {
  for_each = local.node_pools
  source   = "./gke_node_pool"
  instance = {
    spec = {
      instance_type        = lookup(each.value, "instance_type", null)
      disk_size            = lookup(each.value, "disk_size", null)
      disk_type            = lookup(each.value, "disk_type", "pd-standard")
      min_node_count       = lookup(each.value, "min_node_count", null)
      max_node_count       = lookup(each.value, "max_node_count", null)
      autoscaling_per_zone = lookup(each.value, "autoscaling_per_zone", false)
      taints               = var.instance.spec.taints
      is_public            = lookup(each.value, "is_public", false)
      single_az            = lookup(each.value, "single_az", false)
      spot                 = lookup(each.value, "spot", false)
      labels = merge(local.labels, {
        "facets-cloud-fleet-${var.instance_name}" = each.key
      })
      iam = lookup(each.value, "iam", {})
    }
    advanced = {
      gke = merge({
        node_locations = lookup(each.value, "azs", lookup(var.inputs.network_details.attributes, "zones", null))
        node_config = {
          spot = lookup(each.value, "spot", false)
        }
        },
      lookup(local.gke_advanced, each.key, {}))
    }
  }
  instance_name = each.key
  environment   = var.environment
  inputs        = var.inputs
}
